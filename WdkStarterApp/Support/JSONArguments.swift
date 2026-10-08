import Foundation

enum JSONArguments {
    static func encode<Value: Encodable>(_ value: Value) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    static func transaction(to: String, value: String, confirmationTarget: Int? = nil) throws -> String {
        try encode(Transaction(to: to, value: value, confirmationTarget: confirmationTarget))
    }

    private struct Transaction: Encodable {
        let to: String
        let value: String
        let confirmationTarget: Int?
    }
}
