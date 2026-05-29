#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - ManageGardensView (Pro)
//
// Wireframe: Manage Gardens pushed screen. Lists all gardens with rename /
// delete and an entry point into Create Garden.

public struct ManageGardensView: View {

    @EnvironmentObject private var store: GardenStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var showingCreate = false
    @State private var renamingId: UUID?
    @State private var renameDraft: String = ""
    @State private var deletingId: UUID?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.bmBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        if store.gardens.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.gardens) { g in
                                row(for: g)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Manage gardens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(store.canAddGarden ? Color.bmGreen : Color.bmText3)
                    }
                    .disabled(!store.canAddGarden)
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateGardenView { store.addGarden($0) }
            }
            .alert("Delete garden?",
                   isPresented: Binding(get: { deletingId != nil },
                                        set: { if !$0 { deletingId = nil } })) {
                Button("Cancel", role: .cancel) { deletingId = nil }
                Button("Delete", role: .destructive) {
                    if let id = deletingId { store.deleteGarden(id: id) }
                    deletingId = nil
                }
            } message: {
                Text("Deleting a garden deletes its beds.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🌱").font(.system(size: 38))
            Text("No gardens yet")
                .font(.custom("Fredoka-SemiBold", size: 16))
                .foregroundStyle(Color.bmText1)
            Text("Create your first garden to start planning.")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .bmCard()
    }

    @ViewBuilder
    private func row(for g: Garden) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if renamingId == g.id {
                    TextField("Garden name", text: $renameDraft)
                        .font(.custom("Nunito-Bold", size: 15))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.bmBgSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button("Save") { commitRename(g) }
                        .font(.custom("Fredoka-SemiBold", size: 12))
                        .foregroundStyle(Color.bmGreen)
                } else {
                    Text(g.name)
                        .font(.custom("Nunito-Bold", size: 15))
                        .foregroundStyle(Color.bmText1)
                    Spacer()
                    Text("\(store.beds(in: g.id).count) bed\(store.beds(in: g.id).count == 1 ? "" : "s")")
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                }
            }

            HStack(spacing: 6) {
                miniChip(g.sunlight.shortLabel, color: .bmAmber)
                miniChip(g.soilType.label,       color: .bmGreen)
                miniChip(g.wetness.shortLabel,   color: .bmSky)
            }

            HStack(spacing: 14) {
                Button("Rename") { startRename(g) }
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(Color.bmLilac)
                Button("Delete") { deletingId = g.id }
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(Color.bmRed)
            }
        }
        .padding(14)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }

    private func miniChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.custom("Nunito-Bold", size: 10))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func startRename(_ g: Garden) {
        renamingId = g.id
        renameDraft = g.name
    }

    private func commitRename(_ g: Garden) {
        var updated = g
        let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            updated.name = trimmed
            store.updateGarden(updated)
        }
        renamingId = nil
    }
}
#endif
