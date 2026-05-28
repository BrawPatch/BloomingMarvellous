import Foundation
// US-0006: UIKit import REMOVED — domain models must be platform-agnostic.
// All UIColor / UIImage references belong in the presentation layer.

// MARK: - UserTier
public enum UserTier: String, Codable, Equatable {
    case free
    case pro
}

// MARK: - ContentPack
// Mirrors the backend `KNOWN_PACKS` set in backend/lambda/index.mjs.
// Pack purchases are only meaningful for `.pro` users.
public enum ContentPack: String, Codable, Equatable, CaseIterable {
    case exotic = "pack_exotic"
    case edible = "pack_edible"
}

// MARK: - UserModel
// US-0025: Renamed from `userModel` → `UserModel` (PascalCase, Swift API Guidelines)
// US-0007: Conforms to Codable — replaces NSKeyedUnarchiver (OWASP M7)
// US-0026: `user_id`    → `userId`    (camelCase, US-0026)
// US-0027: `first_name` → `firstName` (camelCase, US-0027)
// US-0028: `api_token`  → `apiToken`  (camelCase, US-0028)
public struct UserModel: Codable, Equatable {

    public var userId: Int                       // US-0026
    public var firstName: String                 // US-0027
    public var apiToken: String                  // US-0028 — value never logged (US-0009)
    public var tier: UserTier                    // server-authoritative entitlement
    public var purchasedPacks: [ContentPack]     // only honoured when tier == .pro

    public init(userId: Int,
                firstName: String,
                apiToken: String,
                tier: UserTier = .free,
                purchasedPacks: [ContentPack] = []) {
        self.userId         = userId
        self.firstName      = firstName
        self.apiToken       = apiToken
        self.tier           = tier
        self.purchasedPacks = purchasedPacks
    }
}

// MARK: - Codable keys (maps JSON snake_case → Swift camelCase)
extension UserModel {
    enum CodingKeys: String, CodingKey {
        case userId         = "user_id"
        case firstName      = "first_name"
        case apiToken       = "api_token"
        case tier
        case purchasedPacks = "purchased_packs"
    }

    // Decode tier + purchasedPacks defensively so older login responses
    // (pre-tier rollout) still produce a valid free-tier UserModel.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId    = try c.decode(Int.self,    forKey: .userId)
        self.firstName = try c.decode(String.self, forKey: .firstName)
        self.apiToken  = try c.decode(String.self, forKey: .apiToken)
        self.tier      = try c.decodeIfPresent(UserTier.self,      forKey: .tier) ?? .free
        let rawPacks   = try c.decodeIfPresent([String].self,      forKey: .purchasedPacks) ?? []
        self.purchasedPacks = rawPacks.compactMap(ContentPack.init(rawValue:))
    }
}

// MARK: - Entitlement helpers
extension UserModel {
    /// Whether the user is entitled to a given content pack right now.
    public func owns(_ pack: ContentPack) -> Bool {
        return tier == .pro && purchasedPacks.contains(pack)
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
