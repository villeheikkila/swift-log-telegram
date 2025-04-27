import AsyncHTTPClient
import Foundation
import Logging

public enum TelegramError: Error {
    case invalidResponse
    case failedToEncodeMessage
}

public struct TelegramLogHandler: LogHandler {
    public var logLevel: Logger.Level
    public var metadata = Logger.Metadata()
    public var metadataProvider: Logger.MetadataProvider?

    private let label: String
    private let chatId: String
    private let disableNotification: Bool
    private let token: String
    private let httpClient: HTTPClient
    private let onTelegeramError: @Sendable (_ telegramError: TelegramError) -> Void

    public init(
        logLevel: Logger.Level = .error,
        label: String,
        token: String,
        chatId: String,
        metadataProvider: Logger.MetadataProvider? = nil,
        disableNotification: Bool = false,
        httpClient: HTTPClient = HTTPClient.shared,
        onTelegeramError: @Sendable @escaping (_ telegramError: TelegramError) -> Void = { _ in }
    ) {
        self.logLevel = logLevel
        self.label = label
        self.token = token
        self.chatId = chatId
        self.metadataProvider = metadataProvider
        self.disableNotification = disableNotification
        self.httpClient = httpClient
        self.onTelegeramError = onTelegeramError
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set(newValue) {
            metadata[metadataKey] = newValue
        }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        guard level >= logLevel else { return }
        let meta = self.metadata
            .merging(metadataProvider?.get() ?? [:]) { _, new in new }
            .merging(metadata ?? [:]) { _, new in new }
        let params = MessageParams(
            level: level,
            message: message,
            metadata: meta,
            source: source,
            file: file,
            function: function,
            line: line,
            timestamp: Date.now
        )
        Task {
            do throws(TelegramError) {
                try await sendMessage(params.telegramMessage)
            } catch {
                onTelegeramError(error)
            }
        }
    }

    private func sendMessage(_ message: String) async throws(TelegramError) {
        let payload = TelegramMessage(
            chatId: chatId,
            text: message,
            disableNotification: disableNotification
        )
        var request = HTTPClientRequest(url: "https://api.telegram.org/bot\(token)/sendMessage")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let encodedBody = try encodePayload(payload)
        request.body = .bytes(encodedBody)
        request.headers.add(name: "Accept-Encoding", value: "*")
        do {
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            if response.status == .ok {
                throw TelegramError.invalidResponse
            }
        } catch {
            throw TelegramError.invalidResponse
        }
    }

    private func encodePayload(_ payload: TelegramMessage) throws(TelegramError) -> Data {
        do {
            return try JSONEncoder().encode(payload)
        } catch {
            throw TelegramError.failedToEncodeMessage
        }
    }
}

private struct TelegramMessage: Encodable {
    let chatId: String
    let text: String
    let parseMode: String
    let disableNotification: Bool

    init(chatId: String, text: String, disableNotification: Bool) {
        self.chatId = chatId
        self.text = text
        parseMode = "MarkdownV2"
        self.disableNotification = disableNotification
    }

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case text
        case parseMode = "parse_mode"
        case disableNotification = "disable_notification"
    }
}

struct MessageParams {
    let level: Logger.Level
    let message: Logger.Message
    let metadata: Logger.Metadata
    let source: String
    let file: String
    let function: String
    let line: UInt
    let timestamp: Date

    var telegramMessage: String {
        let formattedTimestamp = timestamp.formatted(
            .dateTime.day().month().year().hour().minute().second())
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        return [
            "*\(escapeMarkdownV2(level.rawValue.uppercased()))* \\| `\(escapeMarkdownV2(formattedTimestamp))`",
            "*Message*\n`\(escapeMarkdownV2(message.description))`",
            "*Source*: `\(escapeMarkdownV2(fileName)):\(line)` in `\(escapeMarkdownV2(function))`",
            !metadata.isEmpty ? "*Metadata*" : nil,
            !metadata.isEmpty
                ? metadata.sorted(by: { $0.key < $1.key })
                    .map { key, value in
                        let formattedValue = value.formattedMarkdownV2()
                        return "  • *\(escapeMarkdownV2(key))*: \(formattedValue)"
                    }
                    .joined(separator: "\n") : nil,
        ]
        .compactMap(\.self)
        .joined(separator: "\n\n")
    }
}

extension Logger.MetadataValue {
    fileprivate func formattedMarkdownV2() -> String {
        switch self {
        case let .string(str):
            if str.contains("\n") || str.count > 30 {
                return """

                    ```
                    \(escapeMarkdownV2(str))
                    ```
                    """
            } else {
                return "`\(escapeMarkdownV2(str))`"
            }

        case let .stringConvertible(conv):
            let description = conv.description
            if description.contains("\n") || description.count > 30 {
                return """

                    ```
                    \(escapeMarkdownV2(description))
                    ```
                    """
            } else {
                return "`\(escapeMarkdownV2(description))`"
            }

        case let .dictionary(metadata):
            if metadata.isEmpty {
                return "`{}`"
            }
            let formattedDict = metadata.sorted(by: { $0.key < $1.key }).map { key, value in
                let escapedKey = escapeMarkdownV2(key)
                let formattedValue = value.formattedMarkdownV2()
                return "  `\(escapedKey)`: \(formattedValue)"
            }.joined(separator: "\n")
            return """

                ```
                {
                \(formattedDict)
                }
                ```
                """

        case let .array(values):
            if values.isEmpty {
                return "`[]`"
            }
            let formattedArray = values.map { value in
                let formattedValue = value.formattedMarkdownV2()
                return "  \(formattedValue)"
            }.joined(separator: ",\n")
            return """

                ```
                [
                \(formattedArray)
                ]
                ```
                """
        }
    }
}

private func escapeMarkdownV2(_ text: String) -> String {
    let specialChars = ["_", "*", "[", "]", "(", ")", "~", "`", ">", "#", "+", "-", "=", "|", "{", "}", ".", "!"]
    var result = text
    for char in specialChars {
        result = result.replacingOccurrences(of: char, with: "\\" + char)
    }
    return result
}
