import Foundation

/// The seven classic tetromino shapes.
enum PieceType: Int, CaseIterable {
    case i, o, t, s, z, j, l

    /// Cells occupied by the shape inside its 4x4 bounding box, with row 0 at
    /// the top of the box.
    ///
    /// Every shape uses the same 4x4 box. That makes rotation a single
    /// coordinate transform instead of seven hand-written tables, and it means
    /// a piece never changes size when it turns.
    var cells: [GridPoint] {
        switch self {
        case .i:
            return [GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1),
                    GridPoint(x: 2, y: 1), GridPoint(x: 3, y: 1)]
        case .o:
            return [GridPoint(x: 1, y: 0), GridPoint(x: 2, y: 0),
                    GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)]
        case .t:
            return [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 1),
                    GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)]
        case .s:
            return [GridPoint(x: 1, y: 0), GridPoint(x: 2, y: 0),
                    GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1)]
        case .z:
            return [GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0),
                    GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)]
        case .j:
            return [GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1),
                    GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)]
        case .l:
            return [GridPoint(x: 2, y: 0), GridPoint(x: 0, y: 1),
                    GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)]
        }
    }
}

/// A tetromino positioned on the playfield.
struct ActivePiece {
    let type: PieceType
    /// Cell offsets inside the 4x4 bounding box.
    var cells: [GridPoint]
    /// Top-left corner of the bounding box, in playfield coordinates.
    var origin: GridPoint

    /// Absolute playfield coordinates of every occupied cell.
    var occupied: [GridPoint] {
        cells.map { GridPoint(x: origin.x + $0.x, y: origin.y + $0.y) }
    }

    /// Rotates the piece clockwise inside its bounding box.
    ///
    /// `O` is rotationally symmetric, so returning it unchanged keeps the
    /// square from drifting sideways on every turn.
    func rotated() -> ActivePiece {
        guard type != .o else { return self }
        let turned = cells.map { GridPoint(x: 3 - $0.y, y: $0.x) }
        return ActivePiece(type: type, cells: turned, origin: origin)
    }
}
