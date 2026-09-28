#if os(iOS) || os(macOS)
import SwiftUI

struct DriftingBackdrop: View {
    var colors: (Color, Color, Color, Color) = (.accentColor, .blue, .accentColor, .blue)
    var intensity: Double = 1.0
    var isAnimated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var size: CGSize = .zero

    var body: some View {
        ZStack {
            if self.size != .zero {
                self.blobField(width: self.size.width, height: self.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .blur(radius: 50)
        .clipped()
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            self.size = newSize
        }
        .ignoresSafeArea()
    }

    private func blobField(width: CGFloat, height: CGFloat) -> some View {
        let unit = max(width, height)
        return ZStack {
            DriftingBlob(
                color: self.colors.0.opacity(0.16 * self.intensity), diameter: unit * 0.95,
                home: CGPoint(x: width * 0.22, y: height * 0.26),
                drift: CGSize(width: unit * 0.10, height: unit * 0.09),
                speed: 0.9, reduceMotion: self.reduceMotion || !self.isAnimated)
            DriftingBlob(
                color: self.colors.1.opacity(0.16 * self.intensity), diameter: unit * 0.9,
                home: CGPoint(x: width * 0.82, y: height * 0.30),
                drift: CGSize(width: -unit * 0.09, height: unit * 0.11),
                speed: 1.18, reduceMotion: self.reduceMotion || !self.isAnimated)
            DriftingBlob(
                color: self.colors.2.opacity(0.15 * self.intensity), diameter: unit * 1.0,
                home: CGPoint(x: width * 0.34, y: height * 0.8),
                drift: CGSize(width: unit * 0.12, height: -unit * 0.09),
                speed: 0.78, reduceMotion: self.reduceMotion || !self.isAnimated)
            DriftingBlob(
                color: self.colors.3.opacity(0.14 * self.intensity), diameter: unit * 0.85,
                home: CGPoint(x: width * 0.78, y: height * 0.82),
                drift: CGSize(width: -unit * 0.11, height: -unit * 0.08),
                speed: 1.05, reduceMotion: self.reduceMotion || !self.isAnimated)
        }
    }
}

private struct DriftingBlob: View {
    let color: Color
    let diameter: CGFloat
    let home: CGPoint
    let drift: CGSize
    let speed: Double
    let reduceMotion: Bool

    @Environment(\.paywallAnimatesDecorations) private var decorativeMotionEnabled
    @State private var isDrifting = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [self.color, self.color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: self.diameter / 2))
            .frame(width: self.diameter, height: self.diameter)
            .scaleEffect(self.isDrifting ? 1.1 : 0.9)
            .position(
                x: self.home.x + (self.isDrifting ? self.drift.width : -self.drift.width),
                y: self.home.y + (self.isDrifting ? self.drift.height : -self.drift.height))
            .onAppear {
                guard !self.reduceMotion, self.decorativeMotionEnabled else { return }
                withAnimation(
                    Tokens.Animations.celebrationDrift
                        .speed(self.speed)
                        .repeatForever(autoreverses: true))
                {
                    self.isDrifting = true
                }
            }
    }
}
#endif
