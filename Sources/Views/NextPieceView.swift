import SwiftUI

/// A small 4x4 preview of the shape that spawns next.
struct NextPieceView: View {
    let type: PieceType
    let cellSize: CGFloat
    let gap: CGFloat

    private var filled: Set<GridPoint> {
        Set(type.cells)
    }

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<4, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(filled.contains(GridPoint(x: column, y: row))
                                  ? type.color
                                  : Color.white.opacity(0.05))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }
}
