import Foundation
import Logging
@testable import SwiftLogTelegram
import Testing

@Test func testBasicMessageFormatting() async throws {
    let fixedDate = Date(timeIntervalSince1970: 1_614_556_800)
    let params = MessageParams(
        level: .error,
        message: "Test error message",
        metadata: [:],
        source: "TestSource",
        file: "/path/to/File.swift",
        function: "testFunction()",
        line: 42,
        timestamp: fixedDate
    )
    let formattedMessage = params.telegramMessage
    #expect(formattedMessage.contains("*ERROR* \\| `"))
    #expect(formattedMessage.contains("*Message*\n`Test error message`"))
    #expect(formattedMessage.contains("*Source*: `File\\.swift:42` in `testFunction\\(\\)`"))
    #expect(!formattedMessage.contains("*Metadata*"))
}

@Test func testMessageFormattingWithMetadata() async throws {
    let fixedDate = Date(timeIntervalSince1970: 1_614_556_800)
    var metadata = Logger.Metadata()
    metadata["key1"] = "value1"
    metadata["key2"] = .stringConvertible(42)
    let params = MessageParams(
        level: .warning,
        message: "Test warning message",
        metadata: metadata,
        source: "TestSource",
        file: "File.swift",
        function: "testFunction()",
        line: 42,
        timestamp: fixedDate
    )
    let formattedMessage = params.telegramMessage
    #expect(formattedMessage.contains("*WARNING* \\| `"))
    #expect(formattedMessage.contains("*Message*\n`Test warning message`"))
    #expect(formattedMessage.contains("*Metadata*"))
    #expect(formattedMessage.contains("  • *key1*: `value1`"))
    #expect(formattedMessage.contains("  • *key2*: `42`"))
}

@Test func testMarkdownEscaping() async throws {
    let fixedDate = Date(timeIntervalSince1970: 1_614_556_800)
    let specialCharsMessage = "Message with *special* _markdown_ [characters] (to) escape!"
    let params = MessageParams(
        level: .info,
        message: .init(stringLiteral: specialCharsMessage),
        metadata: ["special*key": "special*value"],
        source: "TestSource",
        file: "File.swift",
        function: "test*Function()",
        line: 42,
        timestamp: fixedDate
    )
    let formattedMessage = params.telegramMessage
    #expect(formattedMessage.contains("Message with \\*special\\* \\_markdown\\_ \\[characters\\] \\(to\\) escape\\!"))
    #expect(formattedMessage.contains("*special\\*key*: `special\\*value`"))
    #expect(formattedMessage.contains("test\\*Function\\(\\)"))
}

@Test func testAllLogLevels() async throws {
    let fixedDate = Date(timeIntervalSince1970: 1_614_556_800)
    let levels: [Logger.Level] = [.trace, .debug, .info, .notice, .warning, .error, .critical]
    for level in levels {
        let params = MessageParams(
            level: level,
            message: "Test message",
            metadata: [:],
            source: "TestSource",
            file: "File.swift",
            function: "testFunction()",
            line: 42,
            timestamp: fixedDate
        )
        let formattedMessage = params.telegramMessage
        #expect(formattedMessage.contains("*\(level.rawValue.uppercased())* \\| `"))
    }
}
