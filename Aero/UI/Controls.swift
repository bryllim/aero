import SwiftUI

/// A 3×3 grid for choosing where the clock sits on screen.
struct AnchorGrid: View {
    @Binding var selection: Anchor

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        let anchor = Anchor.allCases[row * 3 + column]
                        Button {
                            selection = anchor
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(anchor == selection ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                                .frame(width: 24, height: 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(anchor.accessibilityName)
                        .accessibilityAddTraits(anchor == selection ? .isSelected : [])
                    }
                }
            }
        }
    }
}

private extension Anchor {
    var accessibilityName: String {
        switch self {
        case .topLeading: "Top Left"
        case .top: "Top"
        case .topTrailing: "Top Right"
        case .leading: "Left"
        case .center: "Center"
        case .trailing: "Right"
        case .bottomLeading: "Bottom Left"
        case .bottom: "Bottom"
        case .bottomTrailing: "Bottom Right"
        }
    }
}

struct ThemeSwatch: View {
    let theme: Theme
    let selected: Bool

    var body: some View {
        Circle()
            .fill(Color(hex: theme.background))
            .overlay(Circle().fill(Color(hex: theme.foreground)).padding(7))
            .overlay(Circle().strokeBorder(.separator))
            .frame(width: 26, height: 26)
            .padding(3)
            .overlay(Circle().strokeBorder(.tint, lineWidth: 2).opacity(selected ? 1 : 0))
            .help(theme.name)
            .accessibilityLabel(theme.name)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
