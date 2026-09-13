import SwiftUI

struct GameView: View {
    @StateObject private var game = GameState()

    private let gap: CGFloat = 2
    private let sidebarWidth: CGFloat = 92
    private let outerPadding: CGFloat = 16
    /// Roughly the vertical space the title, controls and spacing need.
    private let chromeHeight: CGFloat = 158

    var body: some View {
        ZStack {
            background

            GeometryReader { geometry in
                let cell = cellSize(fitting: geometry.size)

                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        BoardView(game: game, cellSize: cell, gap: gap)
                            .contentShape(Rectangle())
                            .onTapGesture { game.rotate() }
                            .gesture(boardGesture)

                        sidebar
                    }

                    ControlsView(game: game)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, outerPadding)
                .padding(.top, 8)
            }

            if game.isGameOver {
                overlay(title: "Game Over",
                        subtitle: "Score \(game.score)  ·  Level \(game.level)",
                        buttonTitle: "Play Again") {
                    game.startNewGame()
                }
            } else if game.isPaused {
                overlay(title: "Paused",
                        subtitle: "Level \(game.level)",
                        buttonTitle: "Resume") {
                    game.togglePause()
                }
            }
        }
        .onAppear { game.startTicker() }
        .onDisappear { game.stopTicker() }
    }

    // MARK: - Pieces of the layout

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.08, blue: 0.14),
                     Color(red: 0.13, green: 0.10, blue: 0.23)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TETRIS")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 5) {
                caption("NEXT")
                NextPieceView(type: game.nextType, cellSize: 12, gap: 2)
            }

            stat(title: "SCORE", value: "\(game.score)")
            stat(title: "LEVEL", value: "\(game.level)")
            stat(title: "LINES", value: "\(game.linesCleared)")

            Spacer(minLength: 0)

            sidebarButton(game.isPaused ? "play.fill" : "pause.fill",
                          game.isPaused ? "Resume" : "Pause") {
                game.togglePause()
            }
            .disabled(game.isGameOver)
            .opacity(game.isGameOver ? 0.4 : 1)

            sidebarButton("arrow.counterclockwise", "New") {
                game.startNewGame()
            }
        }
        .frame(width: sidebarWidth, alignment: .leading)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.55))
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            caption(title)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func sidebarButton(_ symbol: String,
                               _ title: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.12))
                )
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }

    private func overlay(title: String,
                         subtitle: String,
                         buttonTitle: String,
                         action: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10).fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.14, green: 0.13, blue: 0.24))
            )
        }
    }

    // MARK: - Gestures and sizing

    /// Swipe sideways to move, down to drop to the bottom, up to rotate.
    /// Tapping the board also rotates.
    private var boardGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height

                if abs(dx) > abs(dy) {
                    if dx > 0 { game.moveRight() } else { game.moveLeft() }
                } else if dy > 0 {
                    game.hardDrop()
                } else {
                    game.rotate()
                }
            }
    }

    /// Picks the largest cell size that keeps the board and controls on screen.
    private func cellSize(fitting size: CGSize) -> CGFloat {
        let boardPadding: CGFloat = 12
        let availableWidth = size.width - outerPadding * 2 - sidebarWidth - 12 - boardPadding
        let availableHeight = size.height - chromeHeight - boardPadding

        let byWidth = (availableWidth - CGFloat(GameState.columns - 1) * gap)
            / CGFloat(GameState.columns)
        let byHeight = (availableHeight - CGFloat(GameState.rows - 1) * gap)
            / CGFloat(GameState.rows)

        return max(10, min(26, floor(min(byWidth, byHeight))))
    }
}

#Preview {
    GameView()
}
