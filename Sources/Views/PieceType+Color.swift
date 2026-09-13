import SwiftUI

/// Shape colours live in the view layer so the game rules stay UI-free.
extension PieceType {
    var color: Color {
        switch self {
        case .i: return Color(red: 0.00, green: 0.76, blue: 0.90)
        case .o: return Color(red: 0.95, green: 0.77, blue: 0.10)
        case .t: return Color(red: 0.64, green: 0.29, blue: 0.85)
        case .s: return Color(red: 0.24, green: 0.79, blue: 0.34)
        case .z: return Color(red: 0.90, green: 0.22, blue: 0.27)
        case .j: return Color(red: 0.18, green: 0.44, blue: 0.90)
        case .l: return Color(red: 0.95, green: 0.53, blue: 0.13)
        }
    }
}
