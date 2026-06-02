#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - HelpTopic
//
// Single place to add / edit per-screen help copy. Each topic carries a
// human-readable title and a longer body with bullet-style guidance.
// ContextualHelpButton renders the catalog as a half-sheet, so adding a
// new screen's help is a one-line change here and a one-line toolbar
// item on the screen.

public enum HelpTopic: String, CaseIterable, Identifiable {
    case home
    case beds
    case bedDetail
    case plantPicker
    case plantDetail
    case bloomPlanner
    case plantingSchedule
    case plantingMap
    case plantManagement
    case settings
    case setup
    case soil

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home:             return "Home"
        case .beds:             return "Garden Beds"
        case .bedDetail:        return "Bed Detail"
        case .plantPicker:      return "Plant Picker"
        case .plantDetail:      return "Plant Detail"
        case .bloomPlanner:     return "Bloom Planner"
        case .plantingSchedule: return "Planting Schedule"
        case .plantingMap:      return "Planting Map"
        case .plantManagement:  return "Plant Management"
        case .settings:         return "Settings"
        case .setup:            return "Setup Wizard"
        case .soil:             return "Garden Conditions"
        }
    }

    public var body: String {
        switch self {
        case .home:
            return """
            Welcome home! This is your dashboard — five little tiles to take you wherever you need to go.

            • Beds — every planting bed you've set up, ready to tweak.
            • Plant Picker — browse hundreds of plants, sorted by when they bloom.
            • Bloom Planner — peek at what'll be flowering each month.
            • Garden Calendar — your sow, transplant, and harvest to-do list.
            • Planting Map — pretty bed layouts you can take into the garden.

            Tap the ⚙️ gear (top-right) for Settings, and the ❓ for help on any screen.
            """
        case .beds:
            return """
            All your beds in one tidy list. Tap any of them to dig into the details.

            • Search by name when the list grows.
            • Status chips help you separate "Planned" from "Active".
            • Hit + (top-right) to add a brand-new bed.
            • "All plants" pulls every species you've picked across every bed into one tidy summary.
            """
        case .bedDetail:
            return """
            Everything that makes this bed special, in one spot.

            • Conditions: soil, wetness, exposure, sunlight. Override the garden defaults if this corner of the garden behaves differently.
            • Crops: the plants you've chosen to bloom here, month by month.
            • Plant layout: set how many of each plant lives here. The bar at the top shows how full the bed is; once a species is at capacity, the + greys out and a friendly "Free up space" nudge appears.
            • Start new season: tidy the bed for the next planting cycle — perennials stay put, annuals clear out, ready for fresh growth.
            """
        case .plantPicker:
            return """
            Your library of plants, sorted by bloom month so you can plan a beautiful year.

            • Matched mode: only suggests plants that'll be happy in your garden.
            • All mode: shows every plant you have access to — handy for browsing.
            • Colour chips help you pick a palette.
            • Tap a tile to see the full plant detail and pop it into your plan.
            """
        case .plantDetail:
            return """
            Everything you need to know about a plant, plus the "Add to plan" controls.

            • Garden / Bed menus: pick where this plant should live.
            • Tap the months you'd like it to bloom — chain a few together to stagger the show.
            • Save locks your choice in.
            • Buy seeds takes you straight to an Amazon search for the Latin name.
            """
        case .bloomPlanner:
            return """
            A month-by-month sneak peek of your future garden in flower.

            • Tap any month to see what's blooming, grouped by bed.
            • "Edit bed" jumps you straight in to make changes on the spot.
            • Quiet months are gaps to fill — perfect places to add new picks.
            """
        case .plantingSchedule:
            return """
            Your gardening to-do list, generated automatically from your picks.

            • Sow tasks land about 12 weeks before each bloom month.
            • Transplant and harvest tasks come from each plant's own windows.
            • Filter by task type, garden, or bed when the list gets busy.
            • Tick the checkbox to mark a task done — it greys out and turns off the daily reminder.
            • "Sync reminders" pushes everything to your iPhone notifications and Calendar (toggle them on in Settings first).
            """
        case .plantingMap:
            return """
            Pretty, printable layouts for each of your beds.

            • Every bed with at least one plant pick gets its own little map.
            • Tap a thumbnail for the full view, the Key, and "Share as A4 PDF".
            • Each plant is a circle sized by how wide it'll grow, with the tallest at the back and a letter to match the Key.
            • Beds with picks but no counts get a "Planned" hint — pop into the Plant layout to set numbers.
            """
        case .plantManagement:
            return """
            One tidy summary of every plant you're growing, across every bed.

            • Grouped by species — the number on the right is the total across the whole garden.
            • Each row shows which bed and garden it's growing in.
            • "Perennial" and "Carried over" badges flag the long-lived survivors.
            • Filter chips help you focus on a single garden or bed when things get bushy.
            """
        case .settings:
            return """
            • Preferences — units, bed dimensions in m or ft, your location, and your growing season.
            • Garden defaults — set the soil, wetness, exposure, sunlight, and acidity for your garden. Beds can override these.
            • Notifications — turn on push reminders and Calendar entries (we'll ask iOS for permission when you toggle them on).
            • Account — reset or change your password, sign out, and (for Pro) manage your subscription. Billing is via the App Store, so cancelling Pro routes you there.
            """
        case .setup:
            return """
            Welcome aboard! Just a few quick questions and we'll have your garden ready.

            • Address — postcode + country, so we can suggest plants that'll thrive in your weather.
            • Garden defaults — soil, wetness, exposure, sunlight, and acidity. Your beds will inherit these.
            • First bed — give it a name, set the size, and you're done. You can always add more later.
            """
        case .soil:
            return """
            Set the growing conditions for your garden or fine-tune them for a single bed.

            • Soil, wetness, exposure, sunlight — these drive the "Matched" suggestions in the Plant Picker.
            • Acidity — leave on neutral if you're not sure; flip it once you've tested.
            • Bed overrides take precedence everywhere the Matched filter runs.
            """
        }
    }
}

// MARK: - ContextualHelpButton
//
// Tiny ? icon that drops into any toolbar / inline location. Tap to
// surface a half-sheet with the topic's body copy.

public struct ContextualHelpButton: View {

    public let topic: HelpTopic
    @State private var showing = false

    public init(topic: HelpTopic) {
        self.topic = topic
    }

    public var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bmText2)
        }
        .accessibilityLabel("Help for \(topic.title)")
        .sheet(isPresented: $showing) {
            HelpSheet(topic: topic)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - HelpSheet

struct HelpSheet: View {

    let topic: HelpTopic
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.bmGreen)
                        Text(topic.title)
                            .font(.custom("Fredoka-SemiBold", size: 20))
                            .foregroundStyle(Color.bmText1)
                    }

                    Text(topic.body)
                        .font(.custom("Nunito-SemiBold", size: 13))
                        .foregroundStyle(Color.bmText2)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("More help is on the way — tap the question mark on any screen.")
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .bmSheetBackdrop()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
        }
    }
}
#endif
