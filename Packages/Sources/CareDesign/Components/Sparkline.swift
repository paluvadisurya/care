import SwiftUI
import Charts

/// A small trend line for tiles and the trend block. Callers downsample to 30 points or fewer.
public struct Sparkline: View {
    public var points: [Double]
    public var color: Color
    public var height: CGFloat
    public var showsLastPoint: Bool

    public init(points: [Double], color: Color = CareColor.violet, height: CGFloat = 48, showsLastPoint: Bool = true) {
        self.points = points
        self.color = color
        self.height = height
        self.showsLastPoint = showsLastPoint
    }

    public var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { index, value in
                AreaMark(x: .value("Index", index), y: .value("Value", value))
                    .foregroundStyle(
                        LinearGradient(colors: [color.opacity(0.32), color.opacity(0)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Index", index), y: .value("Value", value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }
            if showsLastPoint, let last = points.last {
                PointMark(x: .value("Index", points.count - 1), y: .value("Value", last))
                    .foregroundStyle(color)
                    .symbolSize(44)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { $0.clipped(antialiased: true) }
        .frame(height: height)
        .accessibilityLabel(Text("Trend over \(points.count) points"))
    }
}

/// Seven or fourteen days of mood as a strip of bars. Coral for low, amber for the middle, mint for good,
/// and a quiet placeholder for days with nothing logged, because a gap is information too.
public struct MoodStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var values: [Int?]
    public var height: CGFloat

    public init(values: [Int?], height: CGFloat = 34) {
        self.values = values
        self.height = height
    }

    public static func color(for value: Int) -> Color {
        switch value {
        case ...2: CareColor.coral
        case 3: CareColor.amber
        default: CareColor.mint
        }
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Capsule(style: .continuous)
                    .fill(value.map(Self.color(for:)) ?? CareColor.chip)
                    .frame(height: barHeight(value))
                    .frame(maxWidth: .infinity)
                    .animation(CareMotion.snappy(reduced: reduceMotion).delay(Double(index) * 0.012), value: value)
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Mood over \(values.count) days"))
    }

    private func barHeight(_ value: Int?) -> CGFloat {
        guard let value else { return max(5, height * 0.16) }
        // Bars start at a third of the track so a low day still reads as a bar rather than a sliver.
        let ratio = 0.34 + (CGFloat(value) - 1) / 4 * 0.66
        return height * ratio
    }
}
