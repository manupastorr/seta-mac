import SwiftUI
import SetaMacCore

struct BpmRangeControl: View {
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let domain: ClosedRange<Double>
    var width: CGFloat = 176

    @State private var editingMin = false
    @State private var editingMax = false
    @State private var minDraft = ""
    @State private var maxDraft = ""

    private var canReset: Bool {
        minValue > domain.lowerBound || maxValue < domain.upperBound
    }

    var body: some View {
        HStack(spacing: 6) {
            SetaResetButton(disabled: !canReset) {
                minValue = domain.lowerBound
                maxValue = domain.upperBound
            }

            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.12))
                            .frame(height: 4)
                            .padding(.horizontal, 8)

                        let minX = thumbX(for: minValue, width: width)
                        let maxX = thumbX(for: maxValue, width: width)
                        Capsule()
                            .fill(SetaTheme.accent)
                            .frame(width: max(0, maxX - minX), height: 4)
                            .offset(x: minX)

                        thumb(at: minX) { dragMin($0, width: width) }
                        thumb(at: maxX) { dragMax($0, width: width) }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let bpm = bpm(at: value.location.x, width: width)
                                if abs(bpm - minValue) <= abs(bpm - maxValue) {
                                    minValue = min(bpm, maxValue)
                                } else {
                                    maxValue = max(bpm, minValue)
                                }
                            }
                    )
                }
                .frame(width: width, height: 24)

                HStack {
                    bpmEndSlot(value: minValue, alignTrailing: false, editing: $editingMin, draft: $minDraft) {
                        minValue = min(clamped($0), maxValue)
                    }
                    Spacer()
                    bpmEndSlot(value: maxValue, alignTrailing: true, editing: $editingMax, draft: $maxDraft) {
                        maxValue = max(clamped($0), minValue)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 14)
            }
            .frame(height: 38, alignment: .center)
        }
    }

    @ViewBuilder
    private func thumb(at x: CGFloat, onDrag: @escaping (DragGesture.Value) -> Void) -> some View {
        Circle()
            .fill(SetaTheme.accent)
            .frame(width: 16, height: 16)
            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
            .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
            .offset(x: x - 8)
            .gesture(DragGesture(minimumDistance: 0).onChanged(onDrag))
    }

    @ViewBuilder
    private func bpmEndSlot(
        value: Double,
        alignTrailing: Bool,
        editing: Binding<Bool>,
        draft: Binding<String>,
        commit: @escaping (Double) -> Void
    ) -> some View {
        ZStack {
            if editing.wrappedValue {
                TextField("", text: draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SetaTheme.text)
                    .multilineTextAlignment(alignTrailing ? .trailing : .leading)
                    .frame(width: 24, height: 14)
                    .onSubmit {
                        if let parsed = Double(draft.wrappedValue) {
                            commit(clamped(parsed))
                        }
                        editing.wrappedValue = false
                    }
            } else {
                Text("\(Int(value.rounded()))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SetaTheme.muted)
                    .frame(width: 24, height: 14, alignment: alignTrailing ? .trailing : .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draft.wrappedValue = "\(Int(value.rounded()))"
                        editing.wrappedValue = true
                    }
            }
        }
    }

    private func thumbX(for value: Double, width: CGFloat) -> CGFloat {
        8 + CGFloat((value - domain.lowerBound) / (domain.upperBound - domain.lowerBound)) * (width - 16)
    }

    private func bpm(at x: CGFloat, width: CGFloat) -> Double {
        let ratio = min(1, max(0, (x - 8) / max(width - 16, 1)))
        return clamped(domain.lowerBound + Double(ratio) * (domain.upperBound - domain.lowerBound))
    }

    private func dragMin(_ gesture: DragGesture.Value, width: CGFloat) {
        minValue = min(bpm(at: gesture.location.x, width: width), maxValue)
    }

    private func dragMax(_ gesture: DragGesture.Value, width: CGFloat) {
        maxValue = max(bpm(at: gesture.location.x, width: width), minValue)
    }

    private func clamped(_ value: Double) -> Double {
        min(domain.upperBound, max(domain.lowerBound, value.rounded()))
    }
}
