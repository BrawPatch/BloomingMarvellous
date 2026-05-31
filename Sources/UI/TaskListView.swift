#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - TaskListView
//
// Wireframe: Task List — "This week" + "Upcoming" sections, checkboxes,
// due dates, filter, Add task. Tasks are derived from planting events in
// the long run; this shell carries a local placeholder list so the journey
// is explorable.

public struct TaskListView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var filter: TaskFilter = .all
    @State private var tasks: [GardenTask] = GardenTask.placeholders
    @State private var showingAdd = false
    @State private var draftTitle = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                filterBar

                ScrollView {
                    VStack(spacing: 16) {
                        section("This week", tasks: thisWeek)
                        section("Upcoming",  tasks: upcoming)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 12)
            .bmSheetBackdrop()
            .bmNavTitle("Tasks", icon: "✅")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.bmGreen)
                    }
                }
            }
            .alert("Add task", isPresented: $showingAdd) {
                TextField("Task title", text: $draftTitle)
                Button("Cancel", role: .cancel) { draftTitle = "" }
                Button("Add") { commitAdd() }
            }
        }
    }

    // MARK: - Filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases) { f in
                    PillButton(f.label, isActive: filter == f, color: .bmGreen) {
                        filter = f
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(_ title: String, tasks: [GardenTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title, icon: title == "This week" ? "📆" : "📅")
            if tasks.isEmpty {
                Text("Nothing scheduled.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText3)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { t in
                        row(for: t)
                    }
                }
            }
        }
    }

    private func row(for t: GardenTask) -> some View {
        Button {
            toggle(t)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(t.done ? Color.bmGreen : Color.bmText3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title)
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundStyle(Color.bmText1)
                        .strikethrough(t.done, color: Color.bmText3)
                    Text("Due: \(t.dueLabel)")
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText2)
                }
                Spacer()
                Text(t.kind.emoji).font(.system(size: 18))
            }
            .padding(12)
            .background(Color.bmBgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.bmBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func toggle(_ t: GardenTask) {
        guard let i = tasks.firstIndex(where: { $0.id == t.id }) else { return }
        tasks[i].done.toggle()
    }

    private func commitAdd() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespaces)
        defer { draftTitle = "" }
        guard !trimmed.isEmpty else { return }
        tasks.append(GardenTask(id: UUID(),
                                title: trimmed,
                                kind: .other,
                                dueDate: Date().addingTimeInterval(86400),
                                done: false))
    }

    private var thisWeek: [GardenTask] {
        filtered.filter { $0.isThisWeek }
    }
    private var upcoming: [GardenTask] {
        filtered.filter { !$0.isThisWeek }
    }
    private var filtered: [GardenTask] {
        switch filter {
        case .all:        return tasks
        case .sow:        return tasks.filter { $0.kind == .sow }
        case .transplant: return tasks.filter { $0.kind == .transplant }
        case .water:      return tasks.filter { $0.kind == .water }
        case .harvest:    return tasks.filter { $0.kind == .harvest }
        }
    }
}

// MARK: - Local task types
//
// These mirror the wireframe categories. When the backend exposes
// /v1/gardens/{id}/tasks they will be replaced by a server-driven model.

public struct GardenTask: Identifiable, Equatable {
    public enum Kind: String, Equatable {
        case sow, transplant, water, harvest, fertilise, other
        public var emoji: String {
            switch self {
            case .sow:        return "🌱"
            case .transplant: return "🪴"
            case .water:      return "💧"
            case .harvest:    return "🧺"
            case .fertilise:  return "🧪"
            case .other:      return "✅"
            }
        }
    }

    public var id: UUID
    public var title: String
    public var kind: Kind
    public var dueDate: Date
    public var done: Bool

    var isThisWeek: Bool {
        Calendar.current.isDate(dueDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var dueLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: dueDate)
    }

    static var placeholders: [GardenTask] {
        let today = Date()
        let cal = Calendar.current
        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: today) ?? today
        }
        return [
            GardenTask(id: UUID(), title: "Sow seeds",   kind: .sow,        dueDate: day(1), done: false),
            GardenTask(id: UUID(), title: "Transplant",  kind: .transplant, dueDate: day(2), done: false),
            GardenTask(id: UUID(), title: "Water",       kind: .water,      dueDate: day(4), done: false),
            GardenTask(id: UUID(), title: "Harvest",     kind: .harvest,    dueDate: day(5), done: false),
            GardenTask(id: UUID(), title: "Fertilise",   kind: .fertilise,  dueDate: day(10), done: false)
        ]
    }
}

enum TaskFilter: String, CaseIterable, Identifiable, Equatable {
    case all, sow, transplant, water, harvest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all:        return "All"
        case .sow:        return "Sow"
        case .transplant: return "Transplant"
        case .water:      return "Water"
        case .harvest:    return "Harvest"
        }
    }
}
#endif
