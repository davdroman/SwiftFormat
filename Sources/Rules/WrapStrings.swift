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
        var metadata = [Formatter.WrapStringMetadata]()
        var metadataIndex = 0
        var measuredLine: (physicalLine: Int, tokenCount: Int, length: Int)?
        var physicalLine = 0
        var stringContexts = [(
            range: ClosedRange<Int>?,
            tokenCountAtStart: Int,
            wrappedOriginalLine: Int?,
            processedPhysicalLine: Int?
        )]()
        formatter.forEachToken(onlyWhereEnabled: false) { index, token in
            if token.isLinebreak {
                physicalLine += 1
            }

            if token.isStartOfScope, token.isStringDelimiter {
                let isQuoted = token.string.contains("\"")
                let shouldProcess = isQuoted && (stringContexts.isEmpty || token.isMultilineStringDelimiter)
                var stringMetadata: Formatter.WrapStringMetadata?
                if stringContexts.isEmpty {
                    metadata = formatter.endOfScope(at: index).map {
                        formatter.wrapStringMetadata(in: index ... $0)
                    } ?? []
                    metadataIndex = 0
                }
                if metadataIndex < metadata.count {
                    stringMetadata = metadata[metadataIndex]
                    metadataIndex += 1
                }
                stringContexts.append((
                    range: stringMetadata.flatMap {
                        guard shouldProcess, $0.isSafe, let length = $0.length else {
                            return nil
                        }
                        return index ... index + length - 1
                    },
                    tokenCountAtStart: formatter.tokens.count,
                    wrappedOriginalLine: nil,
                    processedPhysicalLine: nil
                ))
                return
            }

            if token == .error(""), !stringContexts.isEmpty, stringContexts.last?.range == nil {
                stringContexts.removeLast()
                return
            }

            if token.isEndOfScope, token.isStringDelimiter {
                if !stringContexts.isEmpty {
                    stringContexts.removeLast()
                }
                return
            }

            guard token.isStringBody,
                  let contextIndex = stringContexts.indices.last,
                  let initialStringRange = stringContexts[contextIndex].range
            else {
                return
            }

            guard formatter.options.maxWidth > 0, formatter.isEnabled else {
                return
            }
            if stringContexts[contextIndex].processedPhysicalLine == physicalLine {
                return
            }
            stringContexts[contextIndex].processedPhysicalLine = physicalLine
            let lineLength: Int
            if let measuredLine,
               measuredLine.physicalLine == physicalLine,
               measuredLine.tokenCount == formatter.tokens.count
            {
                lineLength = measuredLine.length
            } else {
                lineLength = formatter.lineLength(at: index)
                measuredLine = (physicalLine, formatter.tokens.count, lineLength)
            }
            guard lineLength > formatter.options.maxWidth else {
                return
            }
            let lineEnd = formatter.endOfLine(at: index)
            let originalLine: Int
            if case let .linebreak(_, line)? = formatter.token(at: lineEnd) {
                originalLine = line
            } else {
                originalLine = formatter.originalLine(at: index)
            }
            if stringContexts[contextIndex].wrappedOriginalLine == originalLine {
                return
            }
            let tokenDelta = formatter.tokens.count - stringContexts[contextIndex].tokenCountAtStart
            let stringRange = (
                initialStringRange.lowerBound ... initialStringRange.upperBound + tokenDelta
            ).autoUpdating(in: formatter)
            let tokenCountBeforeWrapping = formatter.tokens.count
            formatter.wrapStringBody(
                at: index,
                in: stringRange,
                canConvertToMultiline: stringContexts.count == 1
            )
            if formatter.tokens.count != tokenCountBeforeWrapping {
                stringContexts[contextIndex].wrappedOriginalLine = originalLine
            }
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
    struct WrapStringMetadata {
        var startIndex: Int
        var endIndex: Int
        var length: Int?
        var isSafe: Bool
    }

    func wrapStringMetadata(in stringRange: ClosedRange<Int>) -> [WrapStringMetadata] {
        var contexts = [(
            startIndex: Int,
            isValid: Bool,
            containsSourceLocationLiteral: Bool
        )]()
        var metadata = [WrapStringMetadata]()

        func closeContext(at endIndex: Int, isValid: Bool) {
            guard var context = contexts.popLast() else {
                return
            }
            context.isValid = context.isValid && isValid
            metadata.append(WrapStringMetadata(
                startIndex: context.startIndex,
                endIndex: endIndex,
                length: context.isValid ? endIndex - context.startIndex + 1 : nil,
                isSafe: context.isValid && !context.containsSourceLocationLiteral
            ))
            if let parentIndex = contexts.indices.last {
                contexts[parentIndex].isValid = contexts[parentIndex].isValid && context.isValid
                contexts[parentIndex].containsSourceLocationLiteral =
                    contexts[parentIndex].containsSourceLocationLiteral || context.containsSourceLocationLiteral
            }
        }

        guard let tokens = tokens(in: stringRange) else {
            return []
        }
        for (index, token) in zip(tokens.indices, tokens) {
            if token.isStartOfScope, token.isStringDelimiter {
                contexts.append((
                    startIndex: index,
                    isValid: true,
                    containsSourceLocationLiteral: false
                ))
            } else if token == .error("") {
                closeContext(at: index, isValid: false)
            } else if token.isEndOfScope, token.isStringDelimiter {
                closeContext(at: index, isValid: true)
            } else if let contextIndex = contexts.indices.last {
                contexts[contextIndex].isValid = contexts[contextIndex].isValid && !token.isError
                contexts[contextIndex].containsSourceLocationLiteral =
                    contexts[contextIndex].containsSourceLocationLiteral ||
                    token == .keyword("#line") || token == .keyword("#column")
            }
        }

        metadata.sort { $0.startIndex < $1.startIndex }
        var openContexts = [(endIndex: Int, isSafe: Bool)]()
        var unsafeContextCount = 0
        for index in metadata.indices {
            while let context = openContexts.last, context.endIndex < metadata[index].startIndex {
                if !context.isSafe {
                    unsafeContextCount -= 1
                }
                openContexts.removeLast()
            }
            metadata[index].isSafe = metadata[index].isSafe && unsafeContextCount == 0
            let context = (endIndex: metadata[index].endIndex, isSafe: metadata[index].isSafe)
            openContexts.append(context)
            if !context.isSafe {
                unsafeContextCount += 1
            }
        }
        return metadata
    }

    func wrapStringBody(
        at bodyIndex: Int,
        in stringRange: AutoUpdatingRange,
        canConvertToMultiline: Bool
    ) {
        guard options.maxWidth > 0 else {
            return
        }
        let startOfString = stringRange.lowerBound
        var bodyIndex = bodyIndex
        let lineStart = startOfLine(at: bodyIndex)
        let lineEnd = endOfLine(at: bodyIndex)
        let closingLineEnd = endOfLine(at: stringRange.upperBound)
        let hashCount = tokens[startOfString].string.filter { $0 == "#" }.count
        let continuation = "\\" + String(repeating: "#", count: hashCount)
        let followsContinuation = index(
            of: .nonSpaceOrCommentOrLinebreak,
            before: lineStart
        ).map {
            guard case let .stringBody(body) = tokens[$0] else {
                return false
            }
            return body.hasSuffix(continuation)
        } ?? false
        guard !tokens[(stringRange.upperBound + 1) ..< closingLineEnd].contains(where: {
            if case let .commentBody(comment) = $0 {
                return followsContinuation && comment.contains("swiftformat:options:this") ||
                    ["disable", "enable", "options"].contains(where: {
                        comment.contains("swiftformat:\($0):previous")
                    })
            }
            return false
        }) else {
            return
        }
        guard !tokens[lineStart ..< lineEnd].contains(where: {
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
                  onSameLine(startOfString, stringRange.upperBound)
            else {
                return
            }

            guard range.map({ $0.contains(startOfString) && $0.contains(stringRange.upperBound) }) ?? true,
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
        var searchIndex = index

        while let currentIndex = self.index(in: searchIndex ..< lineEnd, where: { $0.isStringBody }),
              case let .stringBody(body) = tokens[currentIndex]
        {
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
            searchIndex = currentIndex + 1
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

        guard !selectedOpportunities.isEmpty else {
            return
        }

        for opportunity in selectedOpportunities.reversed() {
            guard case let .stringBody(body) = tokens[opportunity.bodyIndex] else {
                continue
            }
            let breakIndex = body.index(body.startIndex, offsetBy: opportunity.offset)
            var replacement: [Token] = [
                .stringBody(String(body[..<breakIndex]) + continuation),
                linebreakToken(for: opportunity.bodyIndex),
            ]
            if !indent.isEmpty {
                replacement.append(.space(indent))
            }
            if breakIndex < body.endIndex {
                replacement.append(.stringBody(String(body[breakIndex...])))
            }

            let insertedTokenCount = replacement.count - 1
            let insertionIndex = opportunity.bodyIndex + 1
            let rangeBeforeReplacement = range
            replaceToken(at: opportunity.bodyIndex, with: replacement)
            if let rangeBeforeReplacement, insertionIndex == rangeBeforeReplacement.upperBound {
                range = rangeBeforeReplacement.lowerBound ..< rangeBeforeReplacement.upperBound + insertedTokenCount
            }
        }
    }

    func multilineStringDelimiter(for startOfString: Int) -> Token {
        let hashCount = tokens[startOfString].string.filter { $0 == "#" }.count
        return .startOfScope(String(repeating: "#", count: hashCount) + "\"\"\"")
    }

    func stringHasWrapOpportunity(from startOfString: Int, to endOfString: Int) -> Bool {
        var hasContentBefore = false
        var searchIndex = startOfString + 1

        while let currentIndex = index(
            in: searchIndex ..< endOfString,
            where: { $0.isStringBody }
        ), case let .stringBody(body) = tokens[currentIndex] {
            hasContentBefore = hasContentBefore || currentIndex > searchIndex
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
            searchIndex = currentIndex + 1
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
