import CoreGraphics
import Foundation

public struct CamelotWheelSegment: Identifiable, Equatable, Sendable {
    public let id: String
    public let code: String
    public let fillHex: String
    public let labelColorHex: String
    public let labelX: CGFloat
    public let labelY: CGFloat
    public let innerRadius: CGFloat
    public let outerRadius: CGFloat
    public let startAngle: CGFloat
    public let endAngle: CGFloat

    public init(
        code: String,
        fillHex: String,
        labelColorHex: String,
        labelX: CGFloat,
        labelY: CGFloat,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat
    ) {
        id = code
        self.code = code
        self.fillHex = fillHex
        self.labelColorHex = labelColorHex
        self.labelX = labelX
        self.labelY = labelY
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.startAngle = startAngle
        self.endAngle = endAngle
    }
}

public enum CamelotWheelGeometry {
    public static let size: CGFloat = 158

    public static func segments() -> [CamelotWheelSegment] {
        let cx = size / 2
        let cy = size / 2
        let rOuter = size / 2 - 3.5
        let rMid = rOuter * (45 / 76)
        let rInner = rOuter * (14 / 76)
        var result: [CamelotWheelSegment] = []

        for slot in 0 ..< 12 {
            let keyNum = slot == 0 ? 12 : slot
            let start = CGFloat(slot) * (.pi * 2 / 12) - .pi / 2
            let end = CGFloat(slot + 1) * (.pi * 2 / 12) - .pi / 2
            let mid = (start + end) / 2
            for (suffix, r0, r1) in [("A", rInner, rMid), ("B", rMid, rOuter)] {
                let code = "\(keyNum)\(suffix)"
                let fillHex = Camelot.colorHex(code)
                let labelR = (r0 + r1) / 2
                let lx = cx + cos(mid) * labelR
                let ly = cy + sin(mid) * labelR
                result.append(
                    CamelotWheelSegment(
                        code: code,
                        fillHex: fillHex,
                        labelColorHex: labelColorHex(for: fillHex),
                        labelX: lx,
                        labelY: ly,
                        innerRadius: r0,
                        outerRadius: r1,
                        startAngle: start,
                        endAngle: end
                    )
                )
            }
        }
        return result
    }

    public static func labelColorHex(for fillHex: String) -> String {
        let raw = fillHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else { return "#ffffff" }
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        let lum = 0.299 * red + 0.587 * green + 0.114 * blue
        return lum > 0.62 ? "#1a1a24" : "#ffffff"
    }

    public static func annularWedgePath(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        let startPoint = CGPoint(
            x: center.x + outerRadius * cos(startAngle),
            y: center.y + outerRadius * sin(startAngle)
        )

        path.move(to: startPoint)
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.addLine(to: CGPoint(
            x: center.x + innerRadius * cos(endAngle),
            y: center.y + innerRadius * sin(endAngle)
        ))
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
