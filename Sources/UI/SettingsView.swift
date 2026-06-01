#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - SettingsView
//
// Wireframe: Settings — Units, Location, Growing season, Reminders, About.
// Persisted locally for now; will move to a /v1/users/me/prefs endpoint.

public struct SettingsView: View {

    public enum Units: String, CaseIterable, Identifiable {
        case metric, imperial
        public var id: String { rawValue }
        public var label: String { rawValue.capitalized }
    }

    private let user: UserModel
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @AppStorage("bm.settings.units")          private var unitsRaw: String = Units.metric.rawValue
    @AppStorage("bm.settings.location")       private var location: String = ""
    @AppStorage("bm.settings.growingSeason")  private var growingSeason: String = "Apr – Oct"
    @AppStorage("bm.settings.remindersOn")    private var remindersOn: Bool = true
    @AppStorage("bm.settings.reminderTime")   private var reminderTimeRaw: Double = defaultReminder

    public init(user: UserModel) { self.user = user }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    preferencesSection
                    notificationsSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .bmSheetBackdrop()
            .bmNavTitle("Settings", icon: "⚙️")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Preferences", icon: "⚙️")

            HStack {
                Text("Units")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Picker("Units", selection: Binding(
                    get: { Units(rawValue: unitsRaw) ?? .metric },
                    set: { unitsRaw = $0.rawValue })) {
                    ForEach(Units.allCases) { u in Text(u.label).tag(u) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                TextField("e.g. Glasgow, UK", text: $location)
                    .font(.custom("Nunito-SemiBold", size: 14))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.bmBgSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.bmBorder, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Growing season")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                TextField("Apr – Oct", text: $growingSeason)
                    .font(.custom("Nunito-SemiBold", size: 14))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.bmBgSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.bmBorder, lineWidth: 1))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Notifications", icon: "🔔")

            Toggle(isOn: $remindersOn) {
                Text("Reminders")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
            }
            .tint(Color.bmGreen)

            if remindersOn {
                DatePicker("Reminder time",
                           selection: Binding(
                                get: { Date(timeIntervalSince1970: reminderTimeRaw) },
                                set: { reminderTimeRaw = $0.timeIntervalSince1970 }),
                           displayedComponents: .hourAndMinute)
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                    .tint(Color.bmGreen)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("About", icon: "ℹ️")
            row(label: "Account", value: user.firstName.isEmpty ? "Gardener" : user.firstName)
            row(label: "Tier", value: user.tier.rawValue.capitalized)
            row(label: "Version", value: appVersion)
            HStack(spacing: 16) {
                Button("Privacy") {}
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(Color.bmLilac)
                Button("Terms") {}
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(Color.bmLilac)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("Nunito-Bold", size: 13))
                .foregroundStyle(Color.bmText1)
            Spacer()
            Text(value)
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    private static var defaultReminder: Double {
        var comps = DateComponents()
        comps.hour = 8
        comps.minute = 0
        return (Calendar.current.date(from: comps) ?? Date()).timeIntervalSince1970
    }
}
#endif
