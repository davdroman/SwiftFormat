//
//  WrapStrings.swift
//  SwiftFormat
//
//  Created by David Roman on 9/3/26.
//  Copyright © 2026 Nick Lockwood. All rights reserved.
//

import Foundation

public extension FormatRule {
    /// Wrap string literals that exceed the configured maximum width.
    static let wrapStrings = FormatRule(
        help: "Wrap string literals that exceed the specified `--max-width`.",
        disabledByDefault: true,
        orderAfter: [.indent],
        options: ["wrap-strings"],
        sharedOptions: ["max-width", "indent", "tab-width", "asset-literals", "linebreaks"]
    ) { formatter in
        guard formatter.options.maxWidth > 0 else {
            return
        }

        var stringContexts = [(
            range: AutoUpdatingRange,
            isQuoted: Bool,
            isValid: Bool,
            processedThroughLineEnd: AutoUpdatingIndex?
        )]()
        formatter.forEachToken(onlyWhereEnabled: false) { index, token in
            if token.isStartOfScope, token.isStringDelimiter,
               let endOfString = formatter.endOfScope(at: index)
            {
                stringContexts.append((
                    range: (index ... endOfString).autoUpdating(in: formatter),
                    isQuoted: token.string.contains("\""),
                    isValid: !formatter.tokens[index ... endOfString].contains(where: \.isError),
                    processedThroughLineEnd: nil
                ))
                return
            }

            if token.isEndOfScope, token.isStringDelimiter {
                if stringContexts.last?.range.upperBound == index {
                    stringContexts.removeLast()
                }
                return
            }

            guard token.isStringBody,
                  let contextIndex = stringContexts.indices.last,
                  stringContexts[contextIndex].isQuoted,
                  stringContexts[contextIndex].isValid,
                  formatter.isEnabled
            else {
                return
            }

            if let processedThroughLineEnd = stringContexts[contextIndex].processedThroughLineEnd {
                guard index > processedThroughLineEnd.index else {
                    return
                }
                processedThroughLineEnd.index = formatter.endOfLine(at: index)
            } else {
                stringContexts[contextIndex].processedThroughLineEnd = formatter.endOfLine(at: index)
                    .autoUpdating(in: formatter)
            }
            formatter.wrapStringBody(
                at: index,
                in: stringContexts[contextIndex].range,
                canConvertToMultiline: stringContexts.count == 1
            )
        }
    } examples: {
        """
        `--wrap-strings multiline-only --max-width 40` (default)

        ```diff
          let text = \"""
        - This is a long string that exceeds the maximum column width
        + This is a long string that exceeds the \\
        + maximum column width
          \"""
        ```

        `--wrap-strings always --max-width 40`

        ```diff
        - let text = "This is a long string that exceeds the maximum column width"
        + let text = \"""
        + This is a long string that exceeds the \\
        + maximum column width
        + \"""
        ```
        """
    }
}

extension Formatter {
    func wrapStringBody(
        at bodyIndex: Int,
        in stringRange: AutoUpdatingRange,
        canConvertToMultiline: Bool
    ) {
        let startOfString = stringRange.lowerBound
        var bodyIndex = bodyIndex
        let lineEnd = endOfLine(at: bodyIndex)
        let directiveScanEnd = min(lineEnd, stringRange.upperBound + 1)
        guard !tokens[bodyIndex ..< directiveScanEnd].contains(where: {
            if case let .commentBody(comment) = $0 {
                return comment.contains("swiftformat:")
            }
            return false
        }) else {
            return
        }

        if !tokens[startOfString].isMultilineStringDelimiter {
            guard canConvertToMultiline,
                  options.wrapStrings == .always,
                  options.swiftVersion == .undefined || options.swiftVersion >= "4",
                  onSameLine(startOfString, stringRange.upperBound),
                  range.map({ $0.contains(startOfString) && $0.contains(stringRange.upperBound) }) ?? true,
                  lineLength(
                      from: startOfLine(at: startOfString),
                      upTo: stringRange.upperBound + 1
                  ) > options.maxWidth,
                  lineLength(upTo: startOfString) + tokenLength(multilineStringDelimiter(for: startOfString)) <= options.maxWidth,
                  stringHasWrapOpportunity(from: startOfString, to: stringRange.upperBound)
            else {
                return
            }

            bodyIndex += convertStringToMultiline(from: startOfString, to: stringRange.upperBound)
        }

        let hashCount = tokens[startOfString].string.filter { $0 == "#" }.count
        let continuation = "\\" + String(repeating: "#", count: hashCount)
        let indent = currentIndentForLine(at: stringRange.upperBound)
        wrapStringLine(at: bodyIndex, continuation: continuation, indent: indent)
    }

    func wrapStringLine(at index: Int, continuation: String, indent: String) {
        let lineWidth = lineLength(at: index)
        guard lineWidth > options.maxWidth else {
            return
        }

        let continuationWidth = tokenLength(.stringBody(continuation))
        let lineEnd = endOfLine(at: index)
        let indentWidth = tokenLength(.space(indent))
        var opportunities = [(bodyIndex: Int, offset: Int, width: Int)]()
        var cumulativeWidth = lineLength(upTo: index)
        var previousBodyEnd = index
        var scopeDepth = 0

        for currentIndex in index ..< lineEnd {
            let token = tokens[currentIndex]
            if token.isStartOfScope {
                scopeDepth += 1
            } else if token.isEndOfScope, scopeDepth > 0 {
                scopeDepth -= 1
            } else if scopeDepth == 0, case let .stringBody(body) = token {
                cumulativeWidth += lineLength(from: previousBodyEnd, upTo: currentIndex)
                let hasContentBefore = cumulativeWidth > indentWidth
                var offset = 0
                var bodyWidth = 0
                var searchStart = body.startIndex
                while let range = body.range(
                    of: "[ \t]+",
                    options: .regularExpression,
                    range: searchStart ..< body.endIndex
                ) {
                    let segment = body[searchStart ..< range.upperBound]
                    offset += segment.count
                    bodyWidth += tokenLength(.stringBody(String(segment)))
                    let suffix = body[range.upperBound...]
                    let hasContentAfter = currentIndex + 1 < lineEnd ||
                        (!suffix.isEmpty && suffix != continuation)
                    if hasContentBefore || searchStart < range.lowerBound, hasContentAfter {
                        opportunities.append((currentIndex, offset, cumulativeWidth + bodyWidth))
                    }
                    searchStart = range.upperBound
                }
                bodyWidth += tokenLength(.stringBody(String(body[searchStart...])))
                cumulativeWidth += bodyWidth
                previousBodyEnd = currentIndex + 1
            }
        }

        var linePrefixWidth = 0
        var lineStartWidth = 0
        var opportunityIndex = opportunities.startIndex
        var selectedOpportunities = [(bodyIndex: Int, offset: Int)]()

        while linePrefixWidth + lineWidth - lineStartWidth > options.maxWidth {
            var lastFittingOpportunity: Int?
            var nextOpportunity = opportunityIndex
            while nextOpportunity < opportunities.endIndex {
                let opportunity = opportunities[nextOpportunity]
                let width = linePrefixWidth + opportunity.width - lineStartWidth + continuationWidth
                if width > options.maxWidth {
                    break
                }
                lastFittingOpportunity = nextOpportunity
                nextOpportunity += 1
            }

            let selectedOpportunity = lastFittingOpportunity ?? nextOpportunity
            guard selectedOpportunity < opportunities.endIndex else {
                break
            }

            let opportunity = opportunities[selectedOpportunity]
            selectedOpportunities.append((opportunity.bodyIndex, opportunity.offset))
            lineStartWidth = opportunity.width
            linePrefixWidth = indentWidth
            opportunityIndex = selectedOpportunity + 1
        }

        if let range {
            selectedOpportunities.removeAll(where: { !range.contains($0.bodyIndex) })
        }

        guard let firstOpportunity = selectedOpportunities.first,
              let lastOpportunity = selectedOpportunities.last
        else {
            return
        }

        let replacementRange = firstOpportunity.bodyIndex ... lastOpportunity.bodyIndex
        var replacement = [Token]()
        var replacementOpportunityIndex = selectedOpportunities.startIndex
        for tokenIndex in replacementRange {
            guard case let .stringBody(body) = tokens[tokenIndex],
                  replacementOpportunityIndex < selectedOpportunities.endIndex,
                  selectedOpportunities[replacementOpportunityIndex].bodyIndex == tokenIndex
            else {
                replacement.append(tokens[tokenIndex])
                continue
            }

            var segmentStart = body.startIndex
            var segmentStartOffset = 0
            while replacementOpportunityIndex < selectedOpportunities.endIndex,
                  selectedOpportunities[replacementOpportunityIndex].bodyIndex == tokenIndex
            {
                let opportunity = selectedOpportunities[replacementOpportunityIndex]
                let breakIndex = body.index(
                    segmentStart,
                    offsetBy: opportunity.offset - segmentStartOffset
                )
                replacement.append(.stringBody(String(body[segmentStart ..< breakIndex]) + continuation))
                replacement.append(linebreakToken(for: tokenIndex))
                if !indent.isEmpty {
                    replacement.append(.space(indent))
                }
                segmentStart = breakIndex
                segmentStartOffset = opportunity.offset
                replacementOpportunityIndex += 1
            }
            if segmentStart < body.endIndex {
                replacement.append(.stringBody(String(body[segmentStart...])))
            }
        }

        let insertedTokenCount = replacement.count - replacementRange.count
        let insertionIndex = replacementRange.upperBound + 1
        let rangeBeforeReplacement = range
        replaceTokens(in: replacementRange, with: replacement)
        if let rangeBeforeReplacement, insertionIndex == rangeBeforeReplacement.upperBound {
            range = rangeBeforeReplacement.lowerBound ..< rangeBeforeReplacement.upperBound + insertedTokenCount
        }
    }

    func multilineStringDelimiter(for startOfString: Int) -> Token {
        let hashCount = tokens[startOfString].string.filter { $0 == "#" }.count
        return .startOfScope(String(repeating: "#", count: hashCount) + "\"\"\"")
    }

    func stringHasWrapOpportunity(from startOfString: Int, to endOfString: Int) -> Bool {
        var hasContentBefore = false
        var scopeDepth = 0

        for currentIndex in startOfString + 1 ..< endOfString {
            let token = tokens[currentIndex]
            if token.isStartOfScope {
                if scopeDepth == 0 {
                    hasContentBefore = true
                }
                scopeDepth += 1
                continue
            } else if token.isEndOfScope, scopeDepth > 0 {
                scopeDepth -= 1
                continue
            } else if scopeDepth > 0 {
                continue
            }

            guard case let .stringBody(body) = token else {
                continue
            }
            var searchStart = body.startIndex
            while let range = body.range(
                of: "[ \t]+",
                options: .regularExpression,
                range: searchStart ..< body.endIndex
            ) {
                hasContentBefore = hasContentBefore || searchStart < range.lowerBound
                let suffix = body[range.upperBound...]
                if hasContentBefore, currentIndex + 1 < endOfString || !suffix.isEmpty {
                    return true
                }
                searchStart = range.upperBound
            }

            hasContentBefore = hasContentBefore || searchStart < body.endIndex || currentIndex + 1 < endOfString
        }

        return false
    }

    func convertStringToMultiline(from startOfString: Int, to endOfString: Int) -> Int {
        let hashCount = tokens[startOfString].string.filter { $0 == "#" }.count
        let hashes = String(repeating: "#", count: hashCount)
        let indent = currentIndentForLine(at: startOfString)
        let linebreak = linebreakToken(for: startOfString)
        var linePrefix = [linebreak]
        if !indent.isEmpty {
            linePrefix.append(.space(indent))
        }

        replaceToken(at: endOfString, with: .endOfScope("\"\"\"" + hashes))
        replaceToken(at: startOfString, with: .startOfScope(hashes + "\"\"\""))
        insert(linePrefix, at: endOfString)
        insert(linePrefix, at: startOfString + 1)
        return linePrefix.count
    }
}
