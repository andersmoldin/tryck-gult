import SwiftUI
import BrytareModell

/// Rutan som visar vad ett val ledde till: stor rubrik och ändringarna en i taget.
struct EffectBox: View {
    let effect: Effect
    @State private var shown = 0

    private var color: Color {
        switch effect.tone {
        case .bad: return .red
        case .neutral: return .yellow
        case .good: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(effect.title)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(color)
                .scaleEffect(shown > 0 ? 1 : 0.4, anchor: .leading)
                .opacity(shown > 0 ? 1 : 0)
            FlowChips(chips: Array(effect.chips.prefix(max(0, shown - 1))), color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 2))
        .task(id: effect) {
            shown = 0
            for step in 1...(effect.chips.count + 1) {
                do { try await Task.sleep(for: .milliseconds(step == 1 ? 50 : 280)) } catch { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = step }
            }
        }
    }
}

/// Chips som radbryts när raden är full.
struct FlowChips: View {
    let chips: [String]
    let color: Color

    var body: some View {
        Flow(spacing: 6) {
            ForEach(chips, id: \.self) { chip in
            Text(chip)
                .font(.subheadline.bold().monospacedDigit())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(color.opacity(0.3)))
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

/// En enkel flödeslayout: lägger barnen på rad och börjar en ny rad när bredden tar slut.
struct Flow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.map { $0.height }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension P {
    var color: Color { Color(hex: info.color) }
    var textColor: Color { Color(hex: info.textColor) }
}
