#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - GardenEvent
//
// A single user-added calendar event. Until /v1/gardens/{id}/events lands,
// these live in memory on PlantingScheduleView. Kept here so the model is
// reusable when the backend comes online.

public struct GardenEvent: Identifiable, Equatable {
    public enum Kind: String, CaseIterable, Identifiable {
        case sow, transplant, water, harvest, fertilise
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .sow:        return "Sow"
            case .transplant: return "Transplant"
            case .water:      return "Water"
            case .harvest:    return "Harvest"
            case .fertilise:  return "Fertilise"
            }
        }
        public var emoji: String {
            switch self {
            case .sow:        return "🌱"
            case .transplant: return "🪴"
            case .water:      return "💧"
            case .harvest:    return "🧺"
            case .fertilise:  return "🧪"
            }
        }
        public var color: Color {
            switch self {
            case .sow:        return .bmGreen
            case .transplant: return .bmLilac
            case .water:      return .bmSky
            case .harvest:    return .bmPeach
            case .fertilise:  return .bmAmber
            }
        }
    }

    public var id: UUID
    public var kind: Kind
    public var date: Date
    public var bedId: UUID?
    public var plantId: String?
    public var notes: String
    public var reminderTime: Date?

    public init(id: UUID = UUID(),
                kind: Kind,
                date: Date,
                bedId: UUID? = nil,
                plantId: String? = nil,
                notes: String = "",
                reminderTime: Date? = nil) {
        self.id = id
        self.kind = kind
        self.date = date
        self.bedId = bedId
        self.plantId = plantId
        self.notes = notes
        self.reminderTime = reminderTime
    }
}

// MARK: - AddEventView (sheet)
//
// Wireframe: Planting Schedule → Add to calendar. Captures event type,
// date (+ optional time), bed selector, plant selector (optional), notes,
// reminder toggle.

public struct AddEventView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    private let onSave: (GardenEvent) -> Void

    @State private var kind: GardenEvent.Kind = .sow
    @State private var date: Date = Date()
    @State private var bedId: UUID?
    @State private var plantId: String?
    @State private var notes: String = ""
    @State private var reminderOn: Bool = false
    @State private var reminderTime: Date = Date()

    public init(onSave: @escaping (GardenEvent) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.bmBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        eventTypeSection
                        dateSection
                        bedSection
                        plantSection
                        notesSection
                        reminderSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Add event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(Color.bmGreen)
                }
            }
            .onAppear {
                if bedId == nil { bedId = store.bedsInSelectedGarden.first?.id }
            }
        }
    }

    private var eventTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Event type", icon: "🗓")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(GardenEvent.Kind.allCases) { k in
                    Button {
                        kind = k
                    } label: {
                        VStack(spacing: 4) {
                            Text(k.emoji).font(.system(size: 24))
                            Text(k.label)
                                .font(.custom("Nunito-Bold", size: 11))
                                .foregroundStyle(kind == k ? .white : Color.bmText2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(kind == k ? k.color : Color.bmBgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(kind == k ? k.color : Color.bmBorder, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("When", icon: "📆")
            DatePicker("Date", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .tint(Color.bmGreen)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var bedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Bed", icon: "🪴")
            if store.bedsInSelectedGarden.isEmpty {
                Text("No beds yet — add one from Garden beds first.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText3)
            } else {
                Picker("Bed", selection: Binding(
                    get: { bedId ?? store.bedsInSelectedGarden.first?.id ?? UUID() },
                    set: { bedId = $0 })) {
                    ForEach(store.bedsInSelectedGarden) { b in
                        Text(b.name).tag(b.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.bmGreen)
                .padding(.horizontal, 12).padding(.vertical, 6)
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

    private var plantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Plant (optional)", icon: "🌸")
            Picker("Plant", selection: Binding(
                get: { plantId ?? "" },
                set: { plantId = $0.isEmpty ? nil : $0 })) {
                Text("— None —").tag("")
                ForEach(library.plants) { p in
                    Text(p.name).tag(p.id)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.bmGreen)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.bmBorder, lineWidth: 1))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Notes", icon: "📝")
            TextField("Optional notes", text: $notes, axis: .vertical)
                .font(.custom("Nunito-SemiBold", size: 14))
                .lineLimit(3...6)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.bmBgSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.bmBorder, lineWidth: 1))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Reminder", icon: "🔔")
            Toggle(isOn: $reminderOn) {
                Text("Remind me")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
            }
            .tint(Color.bmGreen)

            if reminderOn {
                DatePicker("At", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                    .tint(Color.bmGreen)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func save() {
        let event = GardenEvent(kind: kind,
                                date: date,
                                bedId: bedId,
                                plantId: plantId,
                                notes: notes.trimmingCharacters(in: .whitespaces),
                                reminderTime: reminderOn ? reminderTime : nil)
        onSave(event)
        dismiss()
    }
}
#endif
