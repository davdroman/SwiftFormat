//
//  WrapStringsTests.swift
//  SwiftFormatTests
//
//  Created by David Roman on 9/3/26.
//  Copyright © 2026 Nick Lockwood. All rights reserved.
//

import XCTest
@testable import SwiftFormat

final class WrapStringsTests: XCTestCase {
    func testWrapMultilineString() {
        let input = #"""
        let text = """
        This is a very long string that should wrap
        """
        """#
        let output = #"""
        let text = """
        This is a very long \
        string that should wrap
        """
        """#

        testFormatting(for: input, output, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 24))
    }

    func testWrapMultilineStringWithIndentation() {
        let input = #"""
        func makeText() -> String {
            """
                This preserves its leading indentation while wrapping
                """
        }
        """#
        let output = #"""
        func makeText() -> String {
            """
                This preserves its leading \
                indentation while wrapping
                """
        }
        """#
        let outputWithIndent = #"""
        func makeText() -> String {
            """
            This preserves its leading \
            indentation while wrapping
            """
        }
        """#

        testFormatting(for: input, [output, outputWithIndent], rules: [.wrapStrings],
                       options: FormatOptions(maxWidth: 36))
    }

    func testWrapRawMultilineString() {
        let input = ##"""
        let text = #"""
        Raw strings need the matching continuation escape marker
        """#
        """##
        let output = ##"""
        let text = #"""
        Raw strings need the \#
        matching continuation \#
        escape marker
        """#
        """##

        testFormatting(for: input, output, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 30))
    }

    func testWrapMultilineStringAroundInterpolation() {
        let input = #"""
        let text = """
        A long prefix before \(value) and some trailing words
        """
        """#
        let output = #"""
        let text = """
        A long prefix before \
        \(value) and some trailing \
        words
        """
        """#

        testFormatting(for: input, output, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 28))
    }

    func testWrapConsecutiveMultilineStringLinesAfterInterpolation() {
        let input = #"""
        let text = """
        Longprefix\(value) trailing words that should wrap
        Second line also contains enough words to wrap
        """
        """#
        let output = #"""
        let text = """
        Longprefix\(value) \
        trailing words that \
        should wrap
        Second line also \
        contains enough words \
        to wrap
        """
        """#

        testFormatting(for: input, output, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 25))
    }

    func testWrapBeforeExistingContinuation() {
        let input = #"""
        let text = """
        This is a very long line that already has \
        a continuation
        """
        """#
        let output = #"""
        let text = """
        This is a very long \
        line that already has \
        a continuation
        """
        """#

        testFormatting(for: input, output, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 24))
    }

    func testWrapSingleLineStringWhenAlways() {
        let input = #"""
        let text = "This is a very long ordinary string that should wrap"
        """#
        let output = #"""
        let text = """
        This is a very long \
        ordinary string that \
        should wrap
        """
        """#
        var options = FormatOptions(wrapStrings: .always)
        options.maxWidth = 24

        testFormatting(for: input, output, rule: .wrapStrings, options: options)
    }

    func testWrapRawSingleLineStringWhenAlways() {
        let input = ###"""
        let text = ##"A raw string with \##n escape and enough words to wrap safely"##
        """###
        let output = ###"""
        let text = ##"""
        A raw string with \##n \##
        escape and enough \##
        words to wrap safely
        """##
        """###
        var options = FormatOptions(wrapStrings: .always)
        options.maxWidth = 26

        testFormatting(for: input, output, rule: .wrapStrings, options: options)
    }

    func testWrapRawSingleLineStringWithOneHashWhenAlways() {
        let input = ##"""
        let text = #"A raw string with \#n escape and enough words to wrap safely"#
        """##
        let output = ##"""
        let text = #"""
        A raw string with \#n \#
        escape and enough \#
        words to wrap safely
        """#
        """##
        let options = FormatOptions(wrapStrings: .always, maxWidth: 25)

        testFormatting(for: input, output, rule: .wrapStrings, options: options)
    }

    func testWrapSingleLineStringAroundInterpolationWhenAlways() {
        let input = #"""
        let text = "A long prefix before \(value) and some trailing words"
        """#
        let output = #"""
        let text = """
        A long prefix before \
        \(value) and some trailing \
        words
        """
        """#
        var options = FormatOptions(wrapStrings: .always)
        options.maxWidth = 28

        testFormatting(for: input, output, rule: .wrapStrings, options: options)
    }

    func testNoConvertNestedSingleLineStringsWhenAlways() throws {
        let input = #"""
        let text = "prefix \("middle \("inner words") trailing words") more trailing words"
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 24)
        let output = try format(input, rules: [.wrapStrings], options: options).output

        XCTAssertNotEqual(output, input)
        XCTAssertTrue(output.contains(#""middle \("inner words") trailing words""#))
        XCTAssertEqual(try format(output, rules: [.wrapStrings], options: options).output, output)
    }

    func testNoConvertSingleLineStringWithWhitespaceOnlyInNestedStringWhenAlways() {
        let input = #"""
        let text = "prefix\("nested words that are long")suffix"
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 24)

        testFormatting(for: input, rule: .wrapStrings, options: options)
    }

    func testWrapIndentedSingleLineStringWhenAlways() {
        let input = #"""
        struct Foo {
            let text = "This is an indented string that should wrap"
        }
        """#
        let output = #"""
        struct Foo {
            let text = """
            This is an indented \
            string that should wrap
            """
        }
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 28)

        testFormatting(for: input, output, rule: .wrapStrings, options: options)
    }

    func testWrapSingleLineStringWithEscapesWhenAlways() {
        let input = #"""
        let text = "A long string with \"quotes\" and a \\ slash to wrap"
        """#
        let output = #"""
        let text = """
        A long string with \
        \"quotes\" and a \\ slash \
        to wrap
        """
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 28)

        testFormatting(for: input, output, rule: .wrapStrings, options: options)
    }

    func testNoWrapSingleLineString() {
        let input = #"""
        let text = "This is a very long single-line string"
        """#

        testFormatting(for: input, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 20))
    }

    func testNoWrapSingleLineStringWhenMultilineOnly() {
        let input = #"""
        let text = "This is a very long single-line string"
        """#
        var options = FormatOptions(wrapStrings: .multilineOnly)
        options.maxWidth = 20

        testFormatting(for: input, rule: .wrapStrings, options: options)
    }

    func testNoWrapShortSingleLineStringWhenAlways() {
        let input = #"""
        let text = "short words"
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 80)

        testFormatting(for: input, rule: .wrapStrings, options: options)
    }

    func testNoWrapEmptyRawSingleLineStringWhenAlways() {
        let input = ##"""
        let text = #""#
        """##
        let options = FormatOptions(wrapStrings: .always, maxWidth: 13)

        testFormatting(for: input, rule: .wrapStrings, options: options)
    }

    func testNoWrapRawSingleLineStringContainingQuotesWhenAlways() {
        let input = ##"""
        let text = #""""""#
        """##
        let options = FormatOptions(wrapStrings: .always, maxWidth: 13)

        testFormatting(for: input, rule: .wrapStrings, options: options)
    }

    func testNoWrapShortSingleLineStringWithTrailingExpressionWhenAlways() {
        let input = #"""
        let x = "short words" + someVeryLongSuffixName
        let y = "short words" // A very long trailing comment
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 25)

        testFormatting(
            for: input,
            rule: .wrapStrings,
            options: options,
            exclude: [.wrap, .wrapSingleLineComments]
        )
    }

    func testNoWrapUnbreakableOrShortSingleLineStringsWhenAlways() {
        let input = #"""
        let url = "https://example.com/a-very-long-path-without-whitespace"
        let aVeryLongVariableNameThatExceedsTheMaximumWidth = "short"
        """#
        let outputWithWrap = #"""
        let url = "https://example.com/a-very-long-path-without-whitespace"
        let aVeryLongVariableNameThatExceedsTheMaximumWidth =
            "short"
        """#
        var options = FormatOptions(wrapStrings: .always)
        options.maxWidth = 24

        testFormatting(for: input, [input, outputWithWrap], rules: [.wrapStrings], options: options)
    }

    func testNoWrapSingleLineStringWhenSwiftVersionIsBelowFour() {
        let input = #"""
        let text = "This is a very long single-line string"
        """#
        var options = FormatOptions(wrapStrings: .always)
        options.maxWidth = 20
        options.swiftVersion = "3.2"

        testFormatting(for: input, rule: .wrapStrings, options: options)
    }

    func testNoWrapSingleLineRegexWhenAlways() {
        let input = #"""
        let regex = /a very long regex pattern with spaces/
        let extendedRegex = #/another very long regex pattern with spaces/#
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 20)

        testFormatting(for: input, rule: .wrapStrings, options: options, exclude: [.wrap])
    }

    func testNoWrapMalformedMultilineString() {
        let input = #"""
        let text = """
        This is a very long invalid string body"""
        """#
        let options = FormatOptions(maxWidth: 20, fragment: true)

        testFormatting(for: input, rule: .wrapStrings, options: options)
    }

    func testNoWrapAcrossDisableDirectiveInInterpolation() throws {
        let input = #"""
        let text = """
        prefix words \(value /* swiftformat:disable wrapStrings */) trailing words that exceed the width
        """
        """#

        XCTAssertEqual(
            try format(
                input,
                rules: [.wrapStrings],
                options: FormatOptions(maxWidth: 24)
            ).output,
            input
        )
    }

    func testWrapSingleLineStringBeforeTrailingDirectiveWhenAlways() {
        let input = #"""
        let text = "This is a very long ordinary string that should wrap" // swiftformat:disable:next wrapStrings
        """#
        let output = #"""
        let text = """
        This is a very long \
        ordinary string that \
        should wrap
        """ // swiftformat:disable:next wrapStrings
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 24)

        testFormatting(for: input, output, rule: .wrapStrings, options: options, exclude: [.wrap])
    }

    func testWrapMultilineStringWithinFormattingRange() throws {
        let input = #"""
        let text = """
        This is a very long string that should wrap
        """
        """#
        let output = #"""
        let text = """
        This is a very long \
        string that should wrap
        """
        """#

        XCTAssertEqual(
            try format(
                input,
                rules: [.wrapStrings],
                options: FormatOptions(maxWidth: 24),
                lineRange: 2 ... 2
            ).output,
            output
        )
    }

    func testNoConvertSingleLineStringAcrossFormattingRange() throws {
        let input = #"""
        let text = "This is a very long string that should wrap"
        """#
        let tokens = tokenize(input)
        let bodyIndex = try XCTUnwrap(tokens.firstIndex(where: \.isStringBody))

        XCTAssertEqual(
            try sourceCode(for: format(
                tokens,
                rules: [.wrapStrings],
                options: FormatOptions(wrapStrings: .always, maxWidth: 24),
                range: bodyIndex ..< bodyIndex + 1
            ).tokens),
            input
        )
    }

    func testWrapMultilineStringWithoutDuplicatingInterpolationAcrossFormattingRange() throws {
        let input = #"""
        let text = """
        first words enough before \(value) trailing words enough after interpolation
        """
        """#
        let output = #"""
        let text = """
        first words enough \
        before \(value) trailing words enough after interpolation
        """
        """#
        let tokens = tokenize(input)
        let bodyIndex = try XCTUnwrap(tokens.firstIndex(where: \.isStringBody))

        XCTAssertEqual(
            try sourceCode(for: format(
                tokens,
                rules: [.wrapStrings],
                options: FormatOptions(maxWidth: 24),
                range: bodyIndex ..< bodyIndex + 1
            ).tokens),
            output
        )
    }

    func testNoWrapMultilineStringWithoutWhitespace() {
        let input = #"""
        let text = """
        https://example.com/a-very-long-path-without-whitespace
        """
        """#

        testFormatting(for: input, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 20))
    }

    func testNoWrapMultilineStringWhenMaxWidthIsZero() {
        let input = #"""
        let text = """
        This is a very long string that should remain on one line
        """
        """#

        testFormatting(for: input, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 0))
    }

    func testWrapLargeMultilineString() throws {
        let body = Array(repeating: "word", count: 1000).joined(separator: " ")
        let input = """
        let text = \"""
        \(body)
        \"""
        """
        let output = try format(
            input,
            rules: [.wrapStrings],
            options: FormatOptions(maxWidth: 80)
        ).output

        XCTAssertEqual(output.replacingOccurrences(of: "\\\n", with: ""), input)
    }

    func testWrapLargeExistingMultilineString() throws {
        let line = Array(repeating: "word", count: 20).joined(separator: " ")
        let body = Array(repeating: line, count: 500).joined(separator: "\n")
        let input = """
        let text = \"""
        \(body)
        \"""
        """
        let output = try format(
            input,
            rules: [.wrapStrings],
            options: FormatOptions(maxWidth: 80)
        ).output

        XCTAssertEqual(output.replacingOccurrences(of: "\\\n", with: ""), input)
    }

    func testWrapLargeInterpolatedMultilineString() throws {
        let body = Array(repeating: #"\(value) word "#, count: 1000).joined()
        let input = """
        let text = \"\"\"
        \(body)
        \"\"\"
        """
        let output = try format(
            input,
            rules: [.wrapStrings],
            options: FormatOptions(maxWidth: 80)
        ).output

        XCTAssertEqual(output.replacingOccurrences(of: "\\\n", with: ""), input)
    }
}
