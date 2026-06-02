import Foundation

// MARK: - StoreProductID
//
// Placeholder bundle identifiers used by the Phase D StoreKit 2
// scaffolding. Replace each string with the real identifier from App
// Store Connect once the products are configured:
//
//   1. App Store Connect → Apps → Blooming Marvellous → Features
//      → In-App Purchases / Subscriptions.
//   2. Create the auto-renewable subscription for Pro and the two
//      non-consumable content packs.
//   3. Copy each "Product ID" string into the cases below.
//
// The same identifiers must appear in the local `BloomingMarvellous.storekit`
// configuration so the simulator can transact without hitting Apple's
// servers during development.

public enum StoreProductID: String, CaseIterable {
    case proSubscription = "com.bloomingmarvellous.pro.monthly"
    case packExotic      = "com.bloomingmarvellous.pack.exotic"
    case packEdible      = "com.bloomingmarvellous.pack.edible"

    public var isSubscription: Bool {
        switch self {
        case .proSubscription: return true
        case .packExotic, .packEdible: return false
        }
    }

    public var displayName: String {
        switch self {
        case .proSubscription: return "Blooming Marvellous Pro"
        case .packExotic:      return "Exotic Pack"
        case .packEdible:      return "Edible Pack"
        }
    }

    public var emoji: String {
        switch self {
        case .proSubscription: return "✨"
        case .packExotic:      return "🌺"
        case .packEdible:      return "🥕"
        }
    }

    public var shortPitch: String {
        switch self {
        case .proSubscription: return "1,000+ more plants to fall in love with"
        case .packExotic:      return "1,000+ tropical & conservatory beauties"
        case .packEdible:      return "750+ veg, herbs & kitchen-garden favourites"
        }
    }

    public var blurb: String {
        switch self {
        case .proSubscription:
            return "Unlock over 1,000 more plants to play with — plus multi-garden planning, the bed planting map, daily reminders, and the all-plants summary across every bed."
        case .packExotic:
            return "Bring the tropics home — orchids, palms, and conservatory species, with planting windows tuned to UK weather."
        case .packEdible:
            return "Grow your dinner — veg, herbs, and kitchen-garden crops with sow / transplant / harvest dates picked for your climate."
        }
    }

    public var contentPack: ContentPack? {
        switch self {
        case .proSubscription: return nil
        case .packExotic:      return .exotic
        case .packEdible:      return .edible
        }
    }
}
