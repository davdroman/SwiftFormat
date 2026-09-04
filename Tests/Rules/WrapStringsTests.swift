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

    func testWrapMultilineStringAtWidthBoundary() {
        let input = #"""
        let text = """
        1234 5678
        """
        """#
        let output = #"""
        let text = """
        1234 \
        5678
        """
        """#

        testFormatting(for: input, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 9), exclude: [.indent, .wrap])
        testFormatting(for: input, output, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 8), exclude: [.indent, .wrap])
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

    func testWrapNestedMultilineString() {
        let input = #"""
        let text = """
        outer
        \(
            """
            This is a very long nested string that should wrap
            """
        )
        """
        """#
        let output = #"""
        let text = """
        outer
        \(
            """
            This is a very long \
            nested string that \
            should wrap
            """
        )
        """
        """#

        testFormatting(for: input, output, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 30))
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

    func testConvertSingleLineStringAtWidthBoundaryWhenAlways() {
        let input = #"""
        let s = "one two"
        """#
        let output = #"""
        let s = """
        one two
        """
        """#

        testFormatting(
            for: input,
            rule: .wrapStrings,
            options: FormatOptions(wrapStrings: .always, maxWidth: 17)
        )
        testFormatting(
            for: input,
            output,
            rule: .wrapStrings,
            options: FormatOptions(wrapStrings: .always, maxWidth: 16)
        )
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

    func testWrapRawSingleLineStringAroundInterpolationWhenAlways() {
        let input = ##"""
        let text = #"A long prefix before \#(value) and some trailing words"#
        """##
        let output = ##"""
        let text = #"""
        A long prefix before \#
        \#(value) and some trailing \#
        words
        """#
        """##
        let options = FormatOptions(wrapStrings: .always, maxWidth: 30)

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

    func testConvertOutermostStringWithoutConvertingNestedStringsWhenAlways() {
        let input = #"""
        let text = "prefix \("middle \("inner words") trailing words") more trailing words"
        """#
        let output = #"""
        let text = """
        prefix \
        \("middle \("inner words") trailing words") \
        more trailing words
        """
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 24)

        testFormatting(for: input, output, rule: .wrapStrings, options: options)
    }

    func testNoConvertSingleLineStringWithWhitespaceOnlyInNestedStringWhenAlways() {
        let input = #"""
        let text = "prefix\("nested words that are long")suffix"
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 24)

        testFormatting(for: input, rule: .wrapStrings, options: options)
    }

    func testNoConvertSingleLineStringContainingMultilineInterpolation() throws {
        let input = #"""
        let text = "prefix \(1 +
            2) trailing words that exceed the width"
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 24)

        XCTAssertEqual(
            try format(input, rules: [.wrapStrings], options: options).output,
            input
        )
    }

    func testNoWrapStringsContainingSourceLocationLiterals() {
        let input = #"""
        let line = "A long prefix before \(#line) and some trailing words"
        let column = """
        A long prefix before \(#column) and some trailing words
        """
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 24)

        testFormatting(for: input, rule: .wrapStrings, options: options, exclude: [.wrap])
    }

    func testNoWrapNestedMultilineStringInsideStringContainingSourceLocationLiteral() throws {
        let input = #"""
        let text = """
        \(
            """
            This is a very long nested string that would otherwise wrap
            """
        )
        \(#line)
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

    func testWrapSingleLineStringWithTabIndentationWhenAlways() {
        let input = #"""
        struct Foo {
        \#tlet text = "This is an indented string that should wrap"
        }
        """#
        let output = #"""
        struct Foo {
        \#tlet text = """
        \#tThis is an indented \
        \#tstring that should wrap
        \#t"""
        }
        """#
        let options = FormatOptions(
            indent: "\t",
            wrapStrings: .always,
            tabWidth: 2,
            maxWidth: 26
        )

        testFormatting(for: input, output, rule: .wrapStrings, options: options)
    }

    func testWrapMultilineStringAtTab() {
        let input = #"""
        let text = """
        1234\#t5678
        """
        """#
        let output = #"""
        let text = """
        1234\#t\
        5678
        """
        """#
        let options = FormatOptions(tabWidth: 4, maxWidth: 9)

        testFormatting(
            for: input,
            output,
            rule: .wrapStrings,
            options: options,
            exclude: [.indent, .wrap]
        )
    }

    func testWrapStringUsingConfiguredLinebreak() {
        let input = #"""
        let text = """
        This is a very long string that should wrap
        """
        """#.replacingOccurrences(of: "\n", with: "\r\n")
        let output = #"""
        let text = """
        This is a very long \
        string that should wrap
        """
        """#.replacingOccurrences(of: "\n", with: "\r\n")
        let options = FormatOptions(linebreak: "\r\n", maxWidth: 24)

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
        let aVeryLongVariableNameThatExceedsTheMaximumWidth = "short words"
        """#
        let outputWithWrap = #"""
        let url = "https://example.com/a-very-long-path-without-whitespace"
        let aVeryLongVariableNameThatExceedsTheMaximumWidth =
            "short words"
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

    func testNoWrapMalformedStringScopes() throws {
        let inputs = [
            #"""
            let text = "A long unterminated string with words to wrap
            """#,
            ##"""
            let text = #"A long unterminated raw string with words to wrap
            """##,
            #"""
            let text = """
            Long words before \(value
            and trailing words that would otherwise wrap
            """
            """#,
        ]
        let options = FormatOptions(maxWidth: 20, fragment: true)

        for input in inputs {
            XCTAssertEqual(
                try format(input, rules: [.wrapStrings], options: options).output,
                input
            )
        }
    }

    func testNoWrapNestedMultilineStringInsideMalformedString() throws {
        let input = #"""
        let text = """
        \(
            """
            This is a very long nested string that would otherwise wrap
            """
        )
        """#
        let options = FormatOptions(maxWidth: 24, fragment: true)

        XCTAssertEqual(
            try format(input, rules: [.wrapStrings], options: options).output,
            input
        )
    }

    func testMalformedStringDoesNotSuppressFollowingValidString() throws {
        let input = #"""
        let malformed = "An unterminated string
        let valid = "This is a valid string with enough words to wrap"
        """#
        let output = #"""
        let malformed = "An unterminated string
        let valid = """
        This is a valid \
        string with enough \
        words to wrap
        """
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 20, fragment: true)

        XCTAssertEqual(
            try format(input, rules: [.wrapStrings], options: options).output,
            output
        )
    }

    func testMalformedRegexDoesNotSuppressFollowingValidString() throws {
        let input = #"""
        let malformed = /unterminated
        let valid = "This is a valid string with enough words to wrap"
        """#
        let output = #"""
        let malformed = /unterminated
        let valid = """
        This is a valid \
        string with enough \
        words to wrap
        """
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 20, fragment: true)

        XCTAssertEqual(
            try format(input, rules: [.wrapStrings], options: options).output,
            output
        )
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

        let tokens = tokenize(input)
        let trailingBodyIndex = try XCTUnwrap(tokens.lastIndex(where: \.isStringBody))
        XCTAssertEqual(
            try sourceCode(for: format(
                tokens,
                rules: [.wrapStrings],
                options: FormatOptions(maxWidth: 24),
                range: trailingBodyIndex ..< trailingBodyIndex + 1
            ).tokens),
            input
        )
    }

    func testNoConvertSingleLineStringBeforeTrailingDirectiveWhenAlways() {
        let input = #"""
        let first = "This is a very long ordinary string that should wrap" // swiftformat:disable:next wrapStrings
        let second = "This is another very long ordinary string that should stay unchanged"
        let third = "This is a third very long ordinary string that should wrap"
        """#
        let output = #"""
        let first = "This is a very long ordinary string that should wrap" // swiftformat:disable:next wrapStrings
        let second = "This is another very long ordinary string that should stay unchanged"
        let third = """
        This is a third very \
        long ordinary string \
        that should wrap
        """
        """#
        let options = FormatOptions(wrapStrings: .always, maxWidth: 24)

        testFormatting(for: input, output, rule: .wrapStrings, options: options, exclude: [.wrap])
    }

    func testTrailingOptionsDirectiveDoesNotAffectPreviousStringLine() {
        let input = #"""
        let text = """
        This is a very long string that should wrap
        """ // swiftformat:options:this --maxwidth 10
        """#
        let output = #"""
        let text = """
        This is a very long \
        string that should wrap
        """ // swiftformat:options:this --maxwidth 10
        """#

        testFormatting(for: input, output, rule: .wrapStrings,
                       options: FormatOptions(maxWidth: 24), exclude: [.wrap])
    }

    func testNoWrapMultilineStringBeforePreviousDirective() throws {
        let input = #"""
        let text = """
        This  is a very long string that would otherwise wrap
        """ // swiftformat:disable:previous consecutiveSpaces
        """#

        XCTAssertEqual(
            try format(
                input,
                rules: [.consecutiveSpaces, .wrapStrings],
                options: FormatOptions(maxWidth: 24)
            ).output,
            input
        )
    }

    func testWrapMultilineStringAfterWrapInsertsLinebreakInInterpolation() {
        let input = #"""
        let text = """
        prefix words here \(foo(first: 1, second: 2, third: 3)) trailing words that should wrap
        """
        """#
        let output = #"""
        let text = """
        prefix words here \(foo(
            first: 1,
            second: 2,
            third: 3
        )) trailing words that \
        should wrap
        """
        """#
        let options = FormatOptions(wrapStringInterpolation: true, maxWidth: 30)

        testFormatting(for: input, [output], rules: [.wrap, .wrapStrings], options: options)
    }

    func testWrapMultilineStringAfterPersistentMaxWidthDirective() {
        let input = #"""
        // swiftformat:options --maxwidth 20
        let text = """
        This is a very long string that should wrap
        """
        """#
        let output = #"""
        // swiftformat:options --maxwidth 20
        let text = """
        This is a very \
        long string that \
        should wrap
        """
        """#

        testFormatting(
            for: input,
            output,
            rule: .wrapStrings,
            options: FormatOptions(maxWidth: 0),
            exclude: [.wrap]
        )
    }

    func testNoWrapMultilineStringAfterDisablingMaxWidthDirective() {
        let input = #"""
        // swiftformat:options --maxwidth none
        let text = """
        This is a very long string that should remain unchanged
        """
        """#

        testFormatting(
            for: input,
            rule: .wrapStrings,
            options: FormatOptions(maxWidth: 20),
            exclude: [.wrap]
        )
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

    func testConvertSingleLineStringWithinFormattingRange() throws {
        let input = #"""
        let untouched = "This string should remain unchanged despite being long"
        let text = "This is a very long ordinary string that should wrap" // selected
        """#
        let output = #"""
        let untouched = "This string should remain unchanged despite being long"
        let text = """
        This is a very long \
        ordinary string that \
        should wrap
        """ // selected
        """#

        XCTAssertEqual(
            try format(
                input,
                rules: [.wrapStrings],
                options: FormatOptions(wrapStrings: .always, maxWidth: 24),
                lineRange: 2 ... 2
            ).output,
            output
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

    func testDeeplyNestedSingleLineStringsDoNotExhaustResources() throws {
        let depth = 5000
        let literal = String(repeating: "\"prefix \\(", count: depth) +
            "\"leaf\"" + String(repeating: ") suffix\"", count: depth)
        let input = """
        let text = \(literal)
        """
        let options = FormatOptions(wrapStrings: .always, maxWidth: input.count + 1)

        XCTAssertEqual(
            try format(input, rules: [.wrapStrings], options: options).output,
            input
        )
    }

    func testDeeplyNestedMultilineStringsDoNotExhaustResources() throws {
        let depth = 5000
        let openingScopes = (0 ..< depth).flatMap { index in
            [
                Token.stringBody("\\"),
                .startOfScope("("),
                .startOfScope("\"\"\""),
                .linebreak("\n", index + 2),
            ]
        }
        let closingScopes = (0 ..< depth).flatMap { index in
            [
                Token.endOfScope("\"\"\""),
                .endOfScope(")"),
                .linebreak("\n", depth + index + 3),
            ]
        }
        let tokens = [Token.startOfScope("\"\"\""), .linebreak("\n", 1)] +
            openingScopes + [.stringBody("leaf"), .linebreak("\n", depth + 2)] +
            closingScopes + [.endOfScope("\"\"\"")]
        let options = FormatOptions(maxWidth: tokens.count + 1)

        XCTAssertEqual(
            try format(tokens, rules: [.wrapStrings], options: options).tokens,
            tokens
        )
    }

    func testManyInterpolationsOnOneLineDoNotExhaustResources() throws {
        let interpolationCount = 5000
        let interpolations = (0 ..< interpolationCount).flatMap { _ in
            [
                Token.stringBody("x\\"),
                .startOfScope("("),
                .identifier("value"),
                .endOfScope(")"),
            ]
        }
        let tokens = [Token.startOfScope("\"\"\""), .linebreak("\n", 1)] +
            interpolations + [.linebreak("\n", 2), .endOfScope("\"\"\"")]
        let options = FormatOptions(maxWidth: interpolationCount * 10)

        XCTAssertEqual(
            try format(tokens, rules: [.wrapStrings], options: options).tokens,
            tokens
        )
    }

    func testManyStringsOnOneLineDoNotExhaustResources() throws {
        let stringCount = 5000
        let strings = (0 ..< stringCount).flatMap { _ in
            [
                Token.startOfScope("\""),
                .stringBody("value"),
                .endOfScope("\""),
                .delimiter(","),
                .space(" "),
            ]
        }
        let tokens = [Token.startOfScope("[")] + strings + [.endOfScope("]")]
        let options = FormatOptions(wrapStrings: .always, maxWidth: stringCount * 10)

        XCTAssertEqual(
            try format(tokens, rules: [.wrapStrings], options: options).tokens,
            tokens
        )
    }

    func testWrapLargeMultilineString() throws {
        let body = Array(repeating: "word", count: 1000).joined(separator: " ")
        let input = """
        let text = \"""
        \(body)
        \"""
        """
        let options = FormatOptions(maxWidth: 80)
        let output = try format(input, rules: [.wrapStrings], options: options).output

        try assertLargeStringWasWrapped(output, preserving: input, options: options)
    }

    func testWrapLargeExistingMultilineString() throws {
        let line = Array(repeating: "word", count: 20).joined(separator: " ")
        let body = Array(repeating: line, count: 500).joined(separator: "\n")
        let input = """
        let text = \"""
        \(body)
        \"""
        """
        let options = FormatOptions(maxWidth: 80)
        let output = try format(input, rules: [.wrapStrings], options: options).output

        try assertLargeStringWasWrapped(output, preserving: input, options: options)
    }

    func testWrapLargeInterpolatedMultilineString() throws {
        let body = Array(repeating: #"\(value) word "#, count: 1000).joined()
        let input = """
        let text = \"\"\"
        \(body)
        \"\"\"
        """
        let options = FormatOptions(maxWidth: 80)
        let output = try format(input, rules: [.wrapStrings], options: options).output

        try assertLargeStringWasWrapped(output, preserving: input, options: options)
    }

    private func assertLargeStringWasWrapped(
        _ output: String,
        preserving input: String,
        options: FormatOptions
    ) throws {
        XCTAssertNotEqual(output, input)
        XCTAssertTrue(output.contains("\\\n"))
        XCTAssertTrue(output.split(separator: "\n").allSatisfy { $0.count <= options.maxWidth })
        XCTAssertEqual(output.replacingOccurrences(of: "\\\n", with: ""), input)
        XCTAssertEqual(
            try format(output, rules: [.wrapStrings], options: options).output,
            output
        )
    }
}
