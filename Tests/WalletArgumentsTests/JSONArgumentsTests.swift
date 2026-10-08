import Foundation
import XCTest
@testable import WalletArguments

final class JSONArgumentsTests: XCTestCase {
    private func decode<Value: Encodable>(_ value: Value) throws -> Any {
        let encoded = try JSONArguments.encode(value)
        return try JSONSerialization.jsonObject(with: Data(encoded.utf8), options: .fragmentsAllowed)
    }

    func testEveryControlCharacterRoundTripsInSigningMessage() throws {
        for codePoint in 0...31 {
            let message = "before" + String(UnicodeScalar(codePoint)!) + "after"
            XCTAssertEqual(try decode(message) as? String, message, "U+\(String(codePoint, radix: 16))")
        }
    }

    func testSigningMessageRoundTripsWithoutChangingContents() throws {
        let messages = [
            "", "ordinary message", "\"quoted\" \\ /", "line one\nline two\r\t",
            "café e\u{0301} 日本語 🔐", "\u{2028}\u{2029}",
            String(repeating: "long 🔐 message\n", count: 4096)
        ]
        for message in messages {
            XCTAssertEqual(try decode(message) as? String, message)
        }
    }

    func testRecipientCannotChangeTransactionFields() throws {
        let recipients = [
            "0x0000000000000000000000000000000000000000",
            "quoted\"recipient", "back\\slash", "line\nbreak",
            "recipient\",\"value\":\"0\",\"extra\":\"field",
            String((0...31).map { Character(UnicodeScalar($0)!) })
        ]
        let amount = "123456789012345678901234567890"
        for recipient in recipients {
            let expected = ["to": recipient, "value": amount]
            let encoded = try JSONArguments.transaction(to: recipient, value: amount)
            let decoded = try JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: String]
            XCTAssertEqual(decoded, expected)
        }
    }

    func testFeeQuotePreservesStringAmountAndNumericConfirmationTarget() throws {
        let recipient = "quoted\"recipient"
        let encoded = try JSONArguments.transaction(to: recipient, value: "1000", confirmationTarget: 1)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any]
        )
        XCTAssertEqual(Set(decoded.keys), ["to", "value", "confirmationTarget"])
        XCTAssertEqual(decoded["to"] as? String, recipient)
        XCTAssertEqual(decoded["value"] as? String, "1000")
        XCTAssertEqual(decoded["confirmationTarget"] as? Int, 1)
        XCTAssertNil(decoded["confirmationTarget"] as? String)
    }

    func testVerificationKeepsMessageAndSignatureInOrder() throws {
        let arguments = ["message\u{0008}\n🔐", "signature\"\\"]
        XCTAssertEqual(try decode(arguments) as? [String], arguments)
    }

    func testEncodingFailureIsReported() {
        XCTAssertThrowsError(try JSONArguments.encode(["value": Double.nan]))
    }
}
