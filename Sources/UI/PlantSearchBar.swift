#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantSearchBar
//
// Shared search field used by every plant gallery (Plant Picker,
// Plant Management, Bloom Planner month sheet). Matches the look
// of the existing GardenBedsView search and ties into the brand
// chrome via bmBgSoft + bmBorder.

struct PlantSearchBar: View {

    @Binding var text: String
    let placeholder: String

    @FocusState private var focused: Bool

    init(text: Binding<String>, placeholder: String = "Search by name or Latin") {
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.bmText3)
            TextField(placeholder, text: $text)
                .font(.custom("Nunito-SemiBold", size: 14))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($focused)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.bmText3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(focused ? Color.bmGreen : Color.bmBorder, lineWidth: 1.5))
    }
}
#endif
