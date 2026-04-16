import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                fillPath(size: geo.size)
                    .fill(color.opacity(0.15))
                strokePath(size: geo.size)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func strokePath(size: CGSize) -> Path {
        Path { path in
            guard values.count > 1 else { return }
            let step = size.width / CGFloat(max(values.count - 1, 1))
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * step
                let y = size.height * (1 - CGFloat(max(0, min(1, v))))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }

    private func fillPath(size: CGSize) -> Path {
        Path { path in
            guard values.count > 1 else { return }
            let step = size.width / CGFloat(max(values.count - 1, 1))
            path.move(to: CGPoint(x: 0, y: size.height))
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * step
                let y = size.height * (1 - CGFloat(max(0, min(1, v))))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }
}
