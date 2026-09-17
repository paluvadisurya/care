import SwiftUI
import Charts

/// A tiny trend line for tiles and the trend block. Downsampled to 30 points by the caller.
public struct Sparkline: View {
    public var points: [Double]
    public var color: Color
    public var height: CGFloat

    public init(points: [Double], color: Color = CareColor.violet, height: CGFloat = 44) {
        self.points = points
        self.color = color
        self.height = height
    }

    public var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { i, v in
                AreaMark(x: .value("Index", i), y: .value("Value", v))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Index", i), y: .value("Value", v))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: height)
        .accessibilityLabel(Text("Trend of \(points.count) points"))
    }
}

/// Seven or fourteen day strip of mood values. Coral for low, amber for middle, mint for good.
public struct MoodStrip: View {
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
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 3)
                    .fill(v.map(Self.color(for:)) ?? CareColor.chip)
                    .frame(height: v.map { CGFloat($0) / 5 * height } ?? 6)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Mood over \(values.count) days"))
    }
}
