#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - SettingsView
//
// Phase 2 layout:
//   • Preferences      — units (metric / imperial) + length unit (m / ft)
//                        + location + growing season
//   • Garden defaults  — Pro only: soil / wetness / exposure / sunlight /
//                        acidity for the currently selected garden. Lifted
//                        out of HomeView so the dashboard becomes the
//                        5-tile launcher.
//   • Notifications    — push reminders + iCal opt-ins. Wires the prefs;
//                        Phase 7 hooks up UNUserNotificationCenter +
//                        EventKit when the user toggles them on.
//   • Account          — name, tier, password actions, and (Pro) Cancel
//                        Pro membership. Payment is App Store subscriptions
//                        so the cancel flow routes to Apple, doesn't
//                        pretend to cancel billing locally.
//   • About            — version, privacy, terms.

public struct SettingsView: View {

    public enum Units: String, CaseIterable, Identifiable {
        case metric, imperial
        public var id: String { rawValue }
        public var label: String { rawValue.capitalized }
    }

    private let user: UserModel
    private let onLogout: () -> Void
    @EnvironmentObject private var store: GardenStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @AppStorage("bm.settings.units")          private var unitsRaw: String = Units.metric.rawValue
    @AppStorage("bm.settings.location")       private var location: String = ""
    @AppStorage("bm.settings.growingSeason")  private var growingSeason: String = "Apr – Oct"
    @AppStorage("bm.settings.remindersOn")    private var remindersOn: Bool = true
    @AppStorage("bm.settings.reminderTime")   private var reminderTimeRaw: Double = defaultReminder
    @AppStorage(LengthUnit.storageKey)        private var lengthUnitRaw: String = LengthUnit.metres.rawValue

    // Phase 2 notification opt-ins. Phase 7 will read these from
    // UNUserNotificationCenter / EventKit at schedule time.
    @AppStorage("bm.notif.pushOn")            private var pushNotificationsOn: Bool = false
    @AppStorage("bm.notif.icalOn")            private var icalCalendarOn: Bool = false

    @State private var showCancelProConfirm = false
    @State private var showResetPasswordSent = false
    @State private var passwordResetMessage: String = ""
    @State private var showingStore = false

    // Concertina expansion state — Gardens & beds opens by default since
    // that's the most-trafficked section once Beds left the home grid.
    @State private var expandedPreferences  = false
    @State private var expandedGardensBeds  = true
    @State private var expandedGardenDef    = false
    @State private var expandedNotifications = false
    @State private var expandedAccount      = false
    @State private var expandedAbout        = false

    // Garden / bed sheets surfaced from inside the Gardens & beds concertina.
    @State private var showingAddGarden  = false
    @State private var showingManageGardens = false
    @State private var addBedForGardenId: UUID?

    public init(user: UserModel, onLogout: @escaping () -> Void = {}) {
        self.user = user
        self.onLogout = onLogout
    }

    public var body: some View {
        NavigationStack {
            settingsContent
                .bmSheetBackdrop()
                .bmNavTitle("Settings", icon: "⚙️")
                .toolbar { settingsToolbar }
                .modifier(SettingsSheetsModifier(
                    showingAddGarden: $showingAddGarden,
                    showingManageGardens: $showingManageGardens,
                    addBedForGardenId: $addBedForGardenId,
                    showingStore: $showingStore,
                    store: store))
                .alert("Cancel Pro membership?",
                       isPresented: $showCancelProConfirm) {
                    Button("Cancel membership", role: .destructive) { confirmCancelPro() }
                    Button("Keep Pro", role: .cancel) {}
                } message: {
                    Text("You will lose access to all Pro features and content. Your subscription is billed by the App Store — we'll open Apple's subscription page to finish cancelling.")
                }
                .alert("Reset password",
                       isPresented: $showResetPasswordSent) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(passwordResetMessage)
                }
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                concertina("Gardens & beds", icon: "🌿", expanded: $expandedGardensBeds) {
                    gardensBedsSection
                }
                concertina("Preferences", icon: "⚙️", expanded: $expandedPreferences) {
                    preferencesSection
                }
                concertina("Garden defaults", icon: "🌿", expanded: $expandedGardenDef) {
                    gardenDefaultsSection
                }
                concertina("Notifications", icon: "🔔", expanded: $expandedNotifications) {
                    notificationsSection
                }
                concertina("Account", icon: "👤", expanded: $expandedAccount) {
                    accountSection
                }
                concertina("About", icon: "ℹ️", expanded: $expandedAbout) {
                    aboutSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Back") { dismiss() }
                .foregroundStyle(Color.bmText2)
        }
        ToolbarItem(placement: .topBarTrailing) {
            ContextualHelpButton(topic: .settings)
        }
    }

    // MARK: - Sheets + navigation modifier
    //
    // Pulled into its own ViewModifier so the body's modifier chain stays
    // small enough for Swift's type checker — four sheets + one
    // navigationDestination + alerts inline tripped the 30 s budget.

    private struct SettingsSheetsModifier: ViewModifier {
        @Binding var showingAddGarden: Bool
        @Binding var showingManageGardens: Bool
        @Binding var addBedForGardenId: UUID?
        @Binding var showingStore: Bool
        let store: GardenStore

        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $showingAddGarden) {
                    CreateGardenView { garden in
                        store.addGarden(garden)
                        showingAddGarden = false
                    }
                    .environmentObject(store)
                }
                .sheet(isPresented: $showingManageGardens) {
                    ManageGardensView().environmentObject(store)
                }
                .sheet(item: Binding(
                    get: { addBedForGardenId.map(IdHolder.init) },
                    set: { addBedForGardenId = $0?.id })) { holder in
                    AddBedView()
                        .environmentObject(store)
                        .onAppear { store.selectedGardenId = holder.id }
                }
                .sheet(isPresented: $showingStore) {
                    StoreSheet()
                }
        }
    }

    // MARK: - Concertina helper

    @ViewBuilder
    private func concertina<Content: View>(_ label: String,
                                           icon: String,
                                           expanded: Binding<Bool>,
                                           @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: expanded) {
                content()
                    .padding(.top, 8)
            } label: {
                SectionLabel(label, icon: icon)
            }
            .tint(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    // Holder type so we can drive sheet/navigation off an optional UUID
    // (UUID itself isn't Identifiable).
    fileprivate struct IdHolder: Identifiable, Hashable { let id: UUID }

    // MARK: - Gardens & beds
    //
    // New for Phase E: Garden + Bed management lives here instead of on the
    // home tile grid. Free users see their one garden + its beds. Pro users
    // get an extra "Manage gardens" link to add/rename/delete multiple
    // gardens via the existing ManageGardensView sheet.

    @ViewBuilder
    private var gardensBedsSection: some View {
        let isPro = user.tier == .pro
        VStack(alignment: .leading, spacing: 12) {
            ForEach(store.gardens) { garden in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("🌷 \(garden.name)")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundStyle(Color.bmText1)
                        Spacer()
                        if isPro {
                            Button {
                                store.selectedGardenId = garden.id
                                showingManageGardens = true
                            } label: {
                                Text("Edit")
                                    .font(.custom("Fredoka-SemiBold", size: 11))
                                    .foregroundStyle(Color.bmGreen)
                            }
                        }
                    }
                    let beds = store.beds(in: garden.id)
                    if beds.isEmpty {
                        Text("No beds yet — add one to start planning.")
                            .font(.custom("Nunito-SemiBold", size: 11))
                            .foregroundStyle(Color.bmText3)
                    } else {
                        ForEach(beds) { bed in
                            NavigationLink {
                                BedDetailView(bedId: bed.id)
                                    .environmentObject(store)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.bmGreenMid)
                                    Text(bed.name)
                                        .font(.custom("Nunito-SemiBold", size: 13))
                                        .foregroundStyle(Color.bmText1)
                                    Spacer()
                                    Text("\(bed.widthCm)×\(bed.lengthCm) cm")
                                        .font(.custom("Nunito-Bold", size: 10))
                                        .foregroundStyle(Color.bmText3)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.bmText3)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(Color.bmBgSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                store.selectedGardenId = garden.id
                                store.selectedBedId = bed.id
                            })
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        addBedForGardenId = garden.id
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Add a bed")
                                .font(.custom("Fredoka-SemiBold", size: 11))
                        }
                        .foregroundStyle(Color.bmGreen)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .overlay(Capsule().stroke(Color.bmGreen, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                if garden.id != store.gardens.last?.id { Divider() }
            }

            if isPro {
                Button {
                    showingAddGarden = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                        Text("Add another garden")
                            .font(.custom("Fredoka-SemiBold", size: 13))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.bmGreen)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text("Add more gardens by upgrading to Pro.")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            HStack {
                Text("Bed dimensions")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Picker("Bed dimensions", selection: $lengthUnitRaw) {
                    ForEach(LengthUnit.allCases) { u in
                        Text(u.label).tag(u.rawValue)
                    }
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
    }

    // MARK: - Garden defaults (Pro only)

    @ViewBuilder
    private var gardenDefaultsSection: some View {
        if let garden = store.selectedGarden {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(garden.name)
                        .font(.custom("Nunito-Bold", size: 12))
                        .foregroundStyle(Color.bmText3)
                    Tooltip("These apply to every bed in this garden unless the bed overrides them. Bed-level settings always win when present.")
                    Spacer()
                }

                gardenPicker(title: "Soil",
                             selection: gardenBinding(\.soilType, in: garden),
                             options: SoilType.allCases) { $0.label }

                gardenPicker(title: "Wetness",
                             selection: gardenBinding(\.wetness, in: garden),
                             options: Wetness.allCases) { $0.label }

                gardenPicker(title: "Exposure",
                             selection: gardenBinding(\.exposure, in: garden),
                             options: WeatherExposure.allCases) { $0.label }

                gardenPicker(title: "Sunlight",
                             selection: gardenBinding(\.sunlight, in: garden),
                             options: Sunlight.allCases) { $0.label }

                gardenPicker(title: "Acidity",
                             selection: gardenAcidityBinding(in: garden),
                             options: SoilAcidity.allCases) { $0.label }

                Text("Bed-level overrides still take precedence on each bed.")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
                    .padding(.top, 2)
            }
        }
    }

    private func gardenBinding<T: Equatable>(_ keyPath: WritableKeyPath<Garden, T>,
                                             in garden: Garden) -> Binding<T> {
        Binding(
            get: { garden[keyPath: keyPath] },
            set: { newValue in
                var updated = garden
                updated[keyPath: keyPath] = newValue
                store.updateGarden(updated)
            })
    }

    /// Acidity is optional on Garden; the segmented picker can't model nil
    /// so we coerce to `.neutral` while reading and write back through.
    private func gardenAcidityBinding(in garden: Garden) -> Binding<SoilAcidity> {
        Binding(
            get: { garden.acidity ?? .neutral },
            set: { newValue in
                var updated = garden
                updated.acidity = newValue
                store.updateGarden(updated)
            })
    }

    private func gardenPicker<T: Hashable & Identifiable>(title: String,
                                                          selection: Binding<T>,
                                                          options: [T],
                                                          label: @escaping (T) -> String) -> some View {
        HStack {
            Text(title)
                .font(.custom("Nunito-Bold", size: 13))
                .foregroundStyle(Color.bmText1)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options) { o in Text(label(o)).tag(o) }
            }
            .pickerStyle(.menu)
            .tint(Color.bmGreen)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $remindersOn) {
                Text("In-app reminders")
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

            Toggle(isOn: $pushNotificationsOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Push reminders")
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(Color.bmText1)
                    Text("Repeat daily until you tick each task off.")
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                }
            }
            .tint(Color.bmGreen)
            .onChange(of: pushNotificationsOn) { newValue in
                Task { await handlePushToggle(newValue) }
            }

            Toggle(isOn: $icalCalendarOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add to Calendar (iCal)")
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(Color.bmText1)
                    Text("Writes the first instance of each task to your calendar.")
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                }
            }
            .tint(Color.bmGreen)
            .onChange(of: icalCalendarOn) { newValue in
                Task { await handleICalToggle(newValue) }
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            row(label: "Signed in as", value: user.firstName.isEmpty ? "Gardener" : user.firstName)
            row(label: "Tier", value: user.tier.rawValue.capitalized)

            Button { showingStore = true } label: {
                accountRowLabel(user.tier == .free
                                    ? "Upgrade to Pro / buy content packs"
                                    : "Manage content packs",
                                icon: "sparkles")
            }
            .buttonStyle(.plain)

            Button(action: emailResetPassword) {
                accountRowLabel("Reset password (email link)", icon: "envelope")
            }
            .buttonStyle(.plain)

            Button(action: changePassword) {
                accountRowLabel("Change password", icon: "key")
            }
            .buttonStyle(.plain)

            Button(action: {
                onLogout()
                dismiss()
            }) {
                accountRowLabel("Sign out", icon: "rectangle.portrait.and.arrow.right", destructive: true)
            }
            .buttonStyle(.plain)

            if user.tier == .pro {
                Button(action: { showCancelProConfirm = true }) {
                    accountRowLabel("Cancel Pro membership", icon: "xmark.seal", destructive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func accountRowLabel(_ title: String, icon: String, destructive: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(destructive ? Color.red : Color.bmLilac)
            Text(title)
                .font(.custom("Nunito-Bold", size: 13))
                .foregroundStyle(destructive ? Color.red : Color.bmText1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bmText3)
        }
        .padding(.vertical, 4)
    }

    private func emailResetPassword() {
        // Server endpoint is forthcoming; surface a confirmation so the user
        // knows the action was registered. Phase 7 / backend work will wire
        // the actual /v1/users/me/reset-password call.
        passwordResetMessage = "We'll send a reset link to your account email shortly."
        showResetPasswordSent = true
    }

    private func changePassword() {
        passwordResetMessage = "Password change isn't available in this build yet — use the email reset link for now."
        showResetPasswordSent = true
    }

    private func confirmCancelPro() {
        // Apple is the source of truth for subscription state. We route to
        // the App Store subscriptions page; the tier flip happens on the
        // server once Apple confirms cancellation (see Phase 2 roadmap).
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
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

    // MARK: - Phase 7 permission handlers

    @MainActor
    private func handlePushToggle(_ newValue: Bool) async {
        if newValue {
            let granted = await NotificationScheduler.shared.requestPermission()
            if !granted {
                // OS denied — reflect back so the toggle doesn't lie about state.
                pushNotificationsOn = false
            }
        } else {
            NotificationScheduler.shared.cancelAll()
        }
    }

    @MainActor
    private func handleICalToggle(_ newValue: Bool) async {
        if newValue {
            let granted = await CalendarSyncService.shared.requestPermission()
            if !granted { icalCalendarOn = false }
        } else {
            await CalendarSyncService.shared.cancelAll()
        }
    }
}
#endif
