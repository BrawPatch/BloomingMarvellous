import Foundation
// US-0006: UIKit import REMOVED — domain models must be platform-agnostic.
// All UIColor / UIImage references belong in the presentation layer.

// MARK: - UserModel
// US-0025: Renamed from `userModel` → `UserModel` (PascalCase, Swift API Guidelines)
// US-0007: Conforms to Codable — replaces NSKeyedUnarchiver (OWASP M7)
// US-0026: `user_id`    → `userId`    (camelCase, US-0026)
// US-0027: `first_name` → `firstName` (camelCase, US-0027)
// US-0028: `api_token`  → `apiToken`  (camelCase, US-0028)
public struct UserModel: Codable, Equatable {

    public var userId: Int          // US-0026
    public var firstName: String    // US-0027
    public var apiToken: String     // US-0028 — value never logged (US-0009)

    public init(userId: Int, firstName: String, apiToken: String) {
        self.userId = userId
        self.firstName = firstName
        self.apiToken = apiToken
    }
}

// MARK: - Codable keys (maps JSON snake_case → Swift camelCase)
extension UserModel {
    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case firstName  = "first_name"
        case apiToken   = "api_token"
    }
}

// MARK: - Serialisation helpers
// US-0007: Replaces `NSKeyedUnarchiver.unarchiveObject(with:)` with type-safe Codable.
extension UserModel {

    /// Deserialise from JSON data.
    /// - Throws: `DecodingError` if data is malformed — never crashes (replaces `try!`)
    public static func deserialize(from data: Data) throws -> UserModel {
        return try JSONDecoder().decode(UserModel.self, from: data)
    }

    /// Serialise to JSON data.
    /// - Throws: `EncodingError` if encoding fails.
    public func serialize() throws -> Data {
        return try JSONEncoder().encode(self)
    }
}
