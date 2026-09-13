import SwiftUI

struct BoardView: View {
    @ObservedObject var game: GameState

    let cellSize: CGFloat
    let gap: CGFloat
    let padding: CGFloat = 6

    var body: some View {
        let grid = game.displayGrid()
        let active = game.activeCells
        let ghost = game.ghostCells()

        VStack(spacing: gap) {
            ForEach(0..<GameState.rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<GameState.columns, id: \.self) { column in
                        cell(grid: grid, active: active, ghost: ghost, x: column, y: row)
                    }
                }
            }
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func cell(grid: [[PieceType?]],
                      active: Set<GridPoint>,
                      ghost: Set<GridPoint>,
                      x: Int,
                      y: Int) -> some View {
        let point = GridPoint(x: x, y: y)
        let isActive = active.contains(point)

        if let type = grid[y][x] {
            RoundedRectangle(cornerRadius: 3)
                .fill(type.color)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(isActive ? 0.9 : 0.25),
                                lineWidth: isActive ? 1.5 : 0.5)
                )
                .frame(width: cellSize, height: cellSize)
        } else if ghost.contains(point) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .frame(width: cellSize, height: cellSize)
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.05))
                .frame(width: cellSize, height: cellSize)
        }
    }
}
