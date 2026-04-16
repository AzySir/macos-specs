import SwiftUI

struct Donut: View {
    let percent: Double
    let color: Color
    var lineWidth: CGFloat = 6
    var diameter: CGFloat = 44

    var body: some View {
        let fill = min(max(percent / 100.0, 0), 1)
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.55),
                            color,
                            color.opacity(0.85)
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: fill)
            Text("\(Int(round(percent)))%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(width: diameter, height: diameter)
    }
}
