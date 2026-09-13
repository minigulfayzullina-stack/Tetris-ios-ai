import SwiftUI

/// On-screen buttons. The board also accepts gestures; these exist so the game
/// is playable without having to discover them.
struct ControlsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                control(symbol: "arrow.left", title: "Left") { game.moveLeft() }
                control(symbol: "arrow.clockwise", title: "Rotate") { game.rotate() }
                control(symbol: "arrow.right", title: "Right") { game.moveRight() }
            }
            HStack(spacing: 10) {
                control(symbol: "arrow.down", title: "Soft") { game.softDrop() }
                control(symbol: "arrow.down.to.line", title: "Drop") { game.hardDrop() }
            }
        }
        .disabled(game.isGameOver)
    }

    private func control(symbol: String,
                         title: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.12))
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}
