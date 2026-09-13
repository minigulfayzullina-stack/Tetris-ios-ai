import Foundation

/// A single cell coordinate on the playfield.
///
/// `x` is the column (0 leftmost, `GameState.columns - 1` rightmost).
/// `y` is the row (0 at the top, `GameState.rows - 1` at the bottom), which
/// matches how the grid is drawn on screen.
struct GridPoint: Hashable {
    var x: Int
    var y: Int

    static func + (lhs: GridPoint, rhs: GridPoint) -> GridPoint {
        GridPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
