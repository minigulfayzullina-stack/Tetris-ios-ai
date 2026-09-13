import Combine
import Foundation

/// All mutable game state plus the rules that drive it.
///
/// Kept free of SwiftUI on purpose: the rules are the part worth testing, and
/// they can be exercised on their own. Colours live in the view layer
/// (`PieceType+Color.swift`).
final class GameState: ObservableObject {

    // MARK: - Playfield dimensions

    static let columns = 10
    static let rows = 20

    /// Filled lines needed to advance one level.
    static let linesPerLevel = 10
    static let maxLevel = 20

    /// Left edge of a spawning piece. The bounding box is 4 wide,
    /// so this centres it: (10 - 4) / 2 == 3.
    static let spawnOriginX = (columns - 4) / 2

    // MARK: - Published state

    /// Cells that have already come to rest. `nil` means empty.
    @Published private(set) var locked: [[PieceType?]]
    /// The falling piece, if one is in play.
    @Published private(set) var piece: ActivePiece?
    /// The shape that will spawn next.
    @Published private(set) var nextType: PieceType = .t
    @Published private(set) var score = 0
    @Published private(set) var level = 1
    @Published private(set) var linesCleared = 0
    @Published private(set) var isGameOver = false
    @Published var isPaused = false

    // MARK: - Private state

    /// Remaining shapes in the current 7-bag.
    private var bag: [PieceType] = []
    private var ticker: Timer?
    private var accumulator: TimeInterval = 0

    private static let tickInterval: TimeInterval = 0.02

    /// Seconds between automatic drops at the current level.
    var gravityInterval: TimeInterval {
        max(0.08, 0.8 - Double(level - 1) * 0.07)
    }

    /// Cells occupied by the falling piece, for drawing it on top.
    var activeCells: Set<GridPoint> {
        guard let current = piece else { return [] }
        return Set(current.occupied)
    }

    // MARK: - Lifecycle

    init() {
        locked = GameState.emptyGrid()
        prepareNewGame()
    }

    deinit {
        ticker?.invalidate()
    }

    func startNewGame() {
        prepareNewGame()
    }

    /// Starts the gravity timer. Call when the view appears.
    func startTicker() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: GameState.tickInterval, repeats: true) { [weak self] _ in
            self?.timerFired()
        }
        // `.common` keeps gravity running during UI tracking.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    /// Stops the gravity timer. Call when the view disappears.
    func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        accumulator = 0
    }

    // MARK: - Player intents

    func moveLeft() {
        attemptMove(dx: -1, dy: 0)
    }

    func moveRight() {
        attemptMove(dx: 1, dy: 0)
    }

    /// Rotates clockwise, nudging the piece if it would otherwise overlap a
    /// wall or a settled block (a simplified "wall kick").
    func rotate() {
        guard let current = piece, !isGameOver, !isPaused else { return }

        let turned = current.rotated()
        let kicks = [
            GridPoint(x: 0, y: 0),
            GridPoint(x: -1, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: -2, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 0, y: -1)
        ]

        for kick in kicks {
            var candidate = turned
            candidate.origin = GridPoint(x: current.origin.x + kick.x,
                                         y: current.origin.y + kick.y)
            if !collides(candidate) {
                piece = candidate
                return
            }
        }
    }

    /// Drops one row, or locks the piece if it is already resting.
    func softDrop() {
        guard !isGameOver, !isPaused else { return }
        if attemptMove(dx: 0, dy: 1) {
            score += 1
        } else {
            lockPiece()
        }
    }

    /// Drops as far as possible and locks immediately.
    func hardDrop() {
        guard !isGameOver, !isPaused else { return }
        var distance = 0
        while attemptMove(dx: 0, dy: 1) {
            distance += 1
        }
        score += distance * 2
        lockPiece()
    }

    func togglePause() {
        guard !isGameOver else { return }
        isPaused.toggle()
        accumulator = 0
    }

    /// Advances gravity by exactly one step.
    ///
    /// Public so the rules can be driven deterministically in tests, without
    /// waiting on a real timer.
    func tick() {
        guard !isGameOver, !isPaused else { return }
        if !attemptMove(dx: 0, dy: 1) {
            lockPiece()
        }
    }

    // MARK: - Rendering helpers

    /// Settled cells merged with the falling piece.
    func displayGrid() -> [[PieceType?]] {
        var display = locked
        guard let current = piece else { return display }
        for cell in current.occupied where isInside(cell) {
            display[cell.y][cell.x] = current.type
        }
        return display
    }

    /// Where the current piece would come to rest if dropped now.
    func ghostCells() -> Set<GridPoint> {
        guard var landing = piece, !isGameOver else { return [] }

        var candidate = landing
        while true {
            candidate.origin.y += 1
            if collides(candidate) { break }
            landing = candidate
        }
        return Set(landing.occupied)
    }

    // MARK: - Pure rules
    //
    // These take the grid as a parameter instead of reading `locked`, which
    // keeps them easy to reason about and to test in isolation.

    /// True when the piece would overlap a wall, the floor, or a settled cell.
    ///
    /// Rows above the ceiling (`y < 0`) are legal and ignored.
    static func collides(_ candidate: ActivePiece, with grid: [[PieceType?]]) -> Bool {
        for cell in candidate.occupied {
            if cell.x < 0 || cell.x >= columns || cell.y >= rows {
                return true
            }
            if cell.y >= 0, grid[cell.y][cell.x] != nil {
                return true
            }
        }
        return false
    }

    /// Removes every completed row and drops the rows above it down.
    ///
    /// Returns the rebuilt grid and the number of rows that were cleared.
    static func clearLines(in grid: [[PieceType?]]) -> (grid: [[PieceType?]], cleared: Int) {
        let remaining = grid.filter { row in row.contains(where: { $0 == nil }) }
        let cleared = grid.count - remaining.count
        guard cleared > 0 else { return (grid, 0) }

        var rebuilt = remaining
        for _ in 0..<cleared {
            rebuilt.insert(Array(repeating: nil, count: columns), at: 0)
        }
        return (rebuilt, cleared)
    }

    /// Base values — 1 line 100, 2 lines 300, 3 lines 500, 4 lines 800 —
    /// scaled by the level at which they were cleared.
    static func points(forLines lines: Int, level: Int) -> Int {
        let base: Int
        switch lines {
        case 1: base = 100
        case 2: base = 300
        case 3: base = 500
        case 4: base = 800
        default: base = 0
        }
        return base * level
    }

    // MARK: - Internals

    private static func emptyGrid() -> [[PieceType?]] {
        Array(repeating: Array(repeating: nil, count: columns), count: rows)
    }

    private func prepareNewGame() {
        locked = GameState.emptyGrid()
        score = 0
        level = 1
        linesCleared = 0
        isGameOver = false
        isPaused = false
        accumulator = 0
        bag = []
        piece = nil
        nextType = drawFromBag()
        spawn()
    }

    /// Standard "7-bag" randomiser: every shape appears once per bag, so the
    /// player never waits too long for a straight piece.
    private func drawFromBag() -> PieceType {
        if bag.isEmpty {
            bag = PieceType.allCases.shuffled()
        }
        return bag.removeLast()
    }

    private func spawn() {
        let type = nextType
        nextType = drawFromBag()

        let spawned = ActivePiece(type: type,
                                  cells: type.cells,
                                  origin: GridPoint(x: GameState.spawnOriginX, y: 0))

        piece = spawned
        if collides(spawned) {
            isGameOver = true
        }
    }

    /// Moves the piece by the given offset if the result is legal.
    @discardableResult
    private func attemptMove(dx: Int, dy: Int) -> Bool {
        guard var moved = piece, !isGameOver else { return false }
        moved.origin.x += dx
        moved.origin.y += dy
        guard !collides(moved) else { return false }
        piece = moved
        return true
    }

    private func isInside(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.x < GameState.columns
            && point.y >= 0 && point.y < GameState.rows
    }

    private func collides(_ candidate: ActivePiece) -> Bool {
        GameState.collides(candidate, with: locked)
    }

    private func lockPiece() {
        guard let current = piece else { return }

        for cell in current.occupied where isInside(cell) {
            locked[cell.y][cell.x] = current.type
        }
        piece = nil

        clearCompletedLines()
        if !isGameOver {
            spawn()
        }
    }

    private func clearCompletedLines() {
        let result = GameState.clearLines(in: locked)
        guard result.cleared > 0 else { return }

        locked = result.grid
        linesCleared += result.cleared
        score += GameState.points(forLines: result.cleared, level: level)
        level = min(GameState.maxLevel, linesCleared / GameState.linesPerLevel + 1)
    }

    private func timerFired() {
        guard !isGameOver, !isPaused else {
            accumulator = 0
            return
        }
        accumulator += GameState.tickInterval
        guard accumulator >= gravityInterval else { return }
        accumulator = 0
        tick()
    }
}
