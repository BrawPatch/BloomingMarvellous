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
            The Home dashboard is your launcher — five tiles open the workflows you'll spend most of your time in.

            • Beds — manage every planting bed in your garden(s).
            • Plant Picker — browse the plant library by bloom month.
            • Bloom Planner — see what's flowering in each calendar month.
            • Garden Calendar — sow / transplant / harvest schedule.
            • Planting Map — printable A4 layouts for each bed.

            Tap the gear icon (top-right) for Settings, where you'll change units, garden defaults (Pro), notifications, and account.
            """
        case .beds:
            return """
            This is the list of every bed in your garden(s). Tap a bed to open its detail screen.

            • Use the search bar to filter by name.
            • Status chips narrow by Planned vs Active.
            • The + button (top-right) creates a new bed.
            • Pro users also see "All plants" — a single roll-up of every species placed across every bed.
            """
        case .bedDetail:
            return """
            Everything about one bed in one place.

            • Conditions: soil, wetness, exposure, sunlight. Override the garden defaults here per bed if needed.
            • Crops: the bloom-month picks you've assigned to this bed.
            • Plant layout (Pro): set how many of each species are physically in the bed. The fill bar tracks bed area; once you hit capacity for a species the + button greys out and a "Free up space" hint appears.
            • Start new season (Pro): rolls perennials into the next season and clears annuals so the bed is ready for fresh planting.
            """
        case .plantPicker:
            return """
            Browse the plant library by bloom month.

            • Matched mode: filters by your garden's soil / sunlight / wetness / acidity.
            • All mode: every plant your tier is entitled to.
            • Colour chips filter by bloom colour (matches the top 3 nearest bands).
            • Tap a tile to open Plant Detail, where you commit it to a month / bed / garden.
            """
        case .plantDetail:
            return """
            Per-plant editorial card plus the "Add to plan" workflow.

            • Garden / Bed menus (Pro): pick where this plant lives.
            • Bloom month chips: tap one or several to stagger the species across the season.
            • Save commits the change to your plan.
            • Buy seeds opens an Amazon UK affiliate search for the Latin name.
            """
        case .bloomPlanner:
            return """
            A month-by-month preview of what will be flowering in your garden.

            • Tap a month chip to see every species set to bloom that month, grouped by bed (Pro) or by garden (Free).
            • Tap "Edit bed" on a bed card to flip into the bed detail screen and tweak.
            • Use this view to spot gaps in the season — months with few or no picks need more attention.
            """
        case .plantingSchedule:
            return """
            Calendar of sow / transplant / harvest tasks derived from your picks.

            • Sow events are scheduled ~12 weeks before each bloom month.
            • Transplant / harvest use the plant's own earliest-month windows.
            • Filter chips narrow by task type, garden, and bed (all multi-select).
            • Tap the checkbox on a row to mark a task done — it grey-outs and (if push reminders are on) cancels the daily notification.
            • Sync reminders pushes your tasks to iCal / local notifications based on your Settings opt-ins.
            """
        case .plantingMap:
            return """
            Gallery of bed layouts you can print to A4.

            • Every bed with at least one species in its bloom picks appears here.
            • Tap a thumbnail for the full layout, the Key, and the "Share as A4 PDF" action.
            • Circles are sized by plant spread, sorted tallest-back / shortest-front. Letters in the canvas match the Key.
            • Beds without explicit Plant layout counts show a "Planned — open Plant layout to set counts" hint so you know to refine.
            """
        case .plantManagement:
            return """
            Single roll-up of every species you've placed, across every bed and garden.

            • Grouped by species — the count on the right is the total across beds.
            • Each placement row shows which bed / garden it lives in.
            • Perennial and Carried-over badges flag long-lived species and post-rollover survivors.
            • Use the filter chips at the top to narrow by garden / bed.
            """
        case .settings:
            return """
            • Preferences — Units, bed-dimension unit (m/ft), location, growing season.
            • Garden defaults (Pro) — soil / wetness / exposure / sunlight / acidity for the selected garden. Bed overrides still win.
            • Notifications — push reminders + iCal opt-ins. Toggling on requests the OS permission immediately.
            • Account — reset password, change password, and (Pro) cancel Pro membership. Billing is App Store, so cancel routes you to apps.apple.com/account/subscriptions.
            """
        case .setup:
            return """
            First-run wizard. We capture three things:

            • Address — postcode + country, used to bias the Plant Picker for your climate.
            • Garden defaults — soil / wetness / exposure / sunlight / acidity. Beds inherit unless overridden.
            • First bed — name, size, and status. You can add more beds later from the Beds tile (Pro).
            """
        case .soil:
            return """
            Set the conditions for the selected garden or override for a single bed.

            • Soil type, wetness, exposure, sunlight — used by the Matched filter in the Plant Picker.
            • Acidity (pH band) — neutral is the safe default; flip to mildly acidic / alkaline if you've tested the soil.
            • Bed-level overrides stamp through to anywhere the Matched filter runs for that bed.
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
