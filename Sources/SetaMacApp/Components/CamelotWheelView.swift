import SwiftUI
import SetaMacCore

struct CamelotWheelView: View {
    let activeKeys: Set<String>
    let filtering: Bool
    var onToggleKey: (String) -> Void

    private let segments = CamelotWheelGeometry.segments()
    private let size = CamelotWheelGeometry.size

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            for segment in segments {
                let active = activeKeys.contains(segment.code)
                let path = CamelotWheelGeometry.annularWedgePath(
                    center: center,
                    innerRadius: segment.innerRadius,
                    outerRadius: segment.outerRadius,
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle
                )
                var color = Color(hex: segment.fillHex)
                if filtering, !active { color = color.opacity(0.28) }
                context.fill(Path(path), with: .color(color))
                context.stroke(
                    Path(path),
                    with: .color(active ? SetaTheme.accent : Color.black.opacity(0.12)),
                    lineWidth: active ? 1.35 : 0.45
                )
            }

            for segment in segments {
                let active = activeKeys.contains(segment.code)
                let labelColor = Color(hex: segment.labelColorHex)
                    .opacity(filtering && !active ? 0.34 : 1)
                let text = Text(segment.code)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(labelColor)
                context.draw(
                    text,
                    at: CGPoint(x: segment.labelX, y: segment.labelY),
                    anchor: .center
                )
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    if let code = hitTest(at: value.location) {
                        onToggleKey(code)
                    }
                }
        )
    }

    private func hitTest(at point: CGPoint) -> String? {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        var angle = atan2(dy, dx)
        if angle < -.pi / 2 { angle += .pi * 2 }

        return segments.first { segment in
            distance >= segment.innerRadius && distance <= segment.outerRadius
                && angle >= segment.startAngle && angle <= segment.endAngle
        }?.code
    }
}
