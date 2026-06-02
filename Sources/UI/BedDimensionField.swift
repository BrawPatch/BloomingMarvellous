#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - BedDimensionField
//
// Shared bed-size control used by the Setup wizard, AddBedView, and the
// EditBedView form. Renders a label, a manual-entry text field (in the
// gardener's preferred unit, parsing decimals or commas back to cm), and
// +/- buttons that step by 0.5 m or 1 ft depending on the unit.
//
// The model stays in cm (Int) so the rest of the app's area / capacity
// maths is untouched — conversion happens at the binding boundary.

struct BedDimensionField: View {

    let title: String
    @Binding var valueCm: Int
    let unit: LengthUnit
    let range: ClosedRange<Int>

    @State private var draft: String = ""
    @State private var hasFocus: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText2)

            HStack(spacing: 8) {
                stepperButton(.minus)
                TextField("", text: $draft, onEditingChanged: { editing in
                    hasFocus = editing
                    if !editing { commitDraft() }
                }, onCommit: { commitDraft() })
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(Color.bmText1)
                    .padding(.vertical, 8)
                    .frame(minWidth: 70)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(hasFocus ? Color.bmGreen : Color.bmBorder, lineWidth: 1.2))
                Text(unit.suffix)
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText2)
                stepperButton(.plus)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.bmBorder, lineWidth: 1))
        }
        .onAppear { syncDraftFromValue() }
        .onChange(of: valueCm) { _ in
            if !hasFocus { syncDraftFromValue() }
        }
        .onChange(of: unit) { _ in
            syncDraftFromValue()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focused = false
                    commitDraft()
                }
                .foregroundStyle(Color.bmGreen)
            }
        }
    }

    // MARK: - Helpers

    private enum Direction { case plus, minus }

    private func stepperButton(_ dir: Direction) -> some View {
        Button {
            let step = LengthFormat.stepCm(for: unit)
            let next = (dir == .plus) ? valueCm + step : valueCm - step
            valueCm = min(max(range.lowerBound, next), range.upperBound)
            syncDraftFromValue()
        } label: {
            Image(systemName: dir == .plus ? "plus" : "minus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(Circle().fill(Color.bmGreen))
        }
        .buttonStyle(.plain)
    }

    private func syncDraftFromValue() {
        draft = LengthFormat.numericString(cm: valueCm, unit: unit)
    }

    private func commitDraft() {
        guard let parsed = LengthFormat.cmFromString(draft, unit: unit) else {
            syncDraftFromValue()
            return
        }
        let clamped = min(max(range.lowerBound, parsed), range.upperBound)
        valueCm = clamped
        syncDraftFromValue()
    }
}
#endif
