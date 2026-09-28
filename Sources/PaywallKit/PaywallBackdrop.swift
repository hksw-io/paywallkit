#if os(iOS) || os(macOS)
import SwiftUI

struct PaywallBackdrop: View {
    let isThanking: Bool
    let symbols: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var decorationIntensity: Double {
        self.colorScheme == .dark ? 0.50 : 0.55
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Tokens.Colors.background)
                .ignoresSafeArea()

            self.decorationLayer
                .opacity(self.isThanking ? 0 : 1)
                .animation(self.reduceMotion ? nil : Tokens.Animations.thanksChromeFade, value: self.isThanking)

            self.celebrationLayer
        }
        .allowsHitTesting(false)
    }

    private var decorationLayer: some View {
        ZStack {
            DriftingBackdrop(intensity: self.decorationIntensity, isAnimated: false)
                .mask {
                    LinearGradient(
                        colors: [.white, .white, .clear],
                        startPoint: .top,
                        endPoint: .bottom)
                        .ignoresSafeArea()
                }

            if !self.symbols.isEmpty {
                PaywallSymbolWallpaper(symbols: self.symbols)
            }
        }
    }

    private var celebrationLayer: some View {
        ZStack {
            if self.isThanking {
                DriftingBackdrop(intensity: 1.0)
                    .transition(.opacity)
            }
        }
        .animation(self.reduceMotion ? nil : Tokens.Animations.thanksCenter, value: self.isThanking)
    }
}

private struct PaywallSymbolWallpaper: View {
    let symbols: [String]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var tile: Image?

    private static let symbolSize: CGFloat = 24
    private static let spacing: CGFloat = 60
    private static let rowStride = 5

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let tile = self.tile {
                tile.resizable(resizingMode: .tile)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .accessibilityHidden(true)
        .task(id: self.colorScheme) {
            self.tile = Self.renderTile(symbols: self.symbols, colorScheme: self.colorScheme, scale: self.displayScale)
        }
    }

    private static func renderTile(symbols: [String], colorScheme: ColorScheme, scale: CGFloat) -> Image? {
        let period = symbols.count
        let tileSpan = CGFloat(period) * self.spacing
        let tint = colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
        let content = ZStack(alignment: .topLeading) {
            ForEach(-1 ... period, id: \.self) { row in
                ForEach(-1 ... period, id: \.self) { column in
                    Image(systemName: self.symbol(in: symbols, row: row, column: column))
                        .font(.system(size: self.symbolSize, weight: .light))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                        .position(
                            x: CGFloat(column) * self.spacing,
                            y: CGFloat(row) * self.spacing)
                }
            }
        }
        .frame(width: tileSpan, height: tileSpan)
        .clipped()

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.isOpaque = false
        guard let rendered = renderer.cgImage else { return nil }
        return Image(decorative: rendered, scale: scale)
    }

    private static func symbol(in symbols: [String], row: Int, column: Int) -> String {
        let period = symbols.count
        let index = row * self.rowStride + column
        let wrapped = ((index % period) + period) % period
        return symbols[wrapped]
    }
}
#endif
