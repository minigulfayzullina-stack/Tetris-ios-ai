import Foundation

// A tiny assertion harness — no XCTest required, so this runs anywhere Swift
// runs, including Linux.

var passed = 0
var failed = 0

func section(_ name: String) {
    print("\n── \(name)")
}

func check(_ condition: Bool, _ label: String) {
    if condition {
        passed += 1
        print("   ok   \(label)")
    } else {
        failed += 1
        print("   FAIL \(label)")
    }
}

func blankGrid() -> [[PieceType?]] {
    Array(repeating: Array(repeating: nil, count: GameState.columns),
          count: GameState.rows)
}

func fullRow() -> [PieceType?] {
    Array(repeating: PieceType.i as PieceType?, count: GameState.columns)
}

/// Every occupied coordinate in a grid.
func occupied(_ grid: [[PieceType?]]) -> Set<GridPoint> {
    var result = Set<GridPoint>()
    for (y, row) in grid.enumerated() {
        for (x, cell) in row.enumerated() where cell != nil {
            result.insert(GridPoint(x: x, y: y))
        }
    }
    return result
}

// ─────────────────────────────────────────────────────────────────────────────

section("fresh game")
let game = GameState()
check(game.locked.count == GameState.rows, "board has 20 rows")
check(game.locked.allSatisfy { $0.count == GameState.columns }, "each row has 10 columns")
check(game.locked.allSatisfy { row in row.allSatisfy { $0 == nil } }, "board starts empty")
check(game.piece != nil, "a piece is in play")
check(game.piece?.origin.x == GameState.spawnOriginX, "piece spawns centred")
check(game.activeCells.count == 4, "the piece occupies four cells")
check(game.score == 0 && game.level == 1 && game.linesCleared == 0, "score, level, lines reset")
check(!game.isGameOver && !game.isPaused, "not over, not paused")

section("every shape is well formed")
for type in PieceType.allCases {
    check(type.cells.count == 4, "\(type) has four cells")
    check(Set(type.cells).count == 4, "\(type) cells are distinct")
    check(type.cells.allSatisfy { $0.x >= 0 && $0.x < 4 && $0.y >= 0 && $0.y < 4 },
          "\(type) fits the 4x4 box")
}

section("horizontal movement")
let mover = GameState()
for _ in 0..<20 { mover.moveLeft() }
let leftMost = mover.piece?.occupied ?? []
check(leftMost.allSatisfy { $0.x >= 0 }, "cannot pass the left wall")
check(leftMost.contains { $0.x == 0 }, "settles against the left wall")

for _ in 0..<20 { mover.moveRight() }
let rightMost = mover.piece?.occupied ?? []
check(rightMost.allSatisfy { $0.x < GameState.columns }, "cannot pass the right wall")
check(rightMost.contains { $0.x == GameState.columns - 1 }, "settles against the right wall")

section("rotation")
let spinner = GameState()
let before = spinner.piece?.cells ?? []
check(before.count == 4, "piece starts with four cells")
for _ in 0..<4 { spinner.rotate() }
let after = spinner.piece?.cells ?? []
check(Set(before) == Set(after), "four rotations return to the starting shape")
check(after.count == 4, "still four cells after rotating")

let twister = GameState()
twister.rotate()
check(twister.piece?.cells.count == 4, "a single rotation keeps four cells")

// Every rotation of every shape must stay inside the 4x4 box.
var rotationOK = true
for type in PieceType.allCases {
    var piece = ActivePiece(type: type, cells: type.cells, origin: GridPoint(x: 3, y: 0))
    for _ in 0..<4 {
        piece = piece.rotated()
        if piece.cells.contains(where: { $0.x < 0 || $0.x > 3 || $0.y < 0 || $0.y > 3 }) {
            rotationOK = false
        }
        if Set(piece.cells).count != 4 { rotationOK = false }
    }
}
check(rotationOK, "all rotations stay in the box with four distinct cells")

let walled = GameState()
for _ in 0..<20 { walled.moveLeft() }
walled.rotate()
let kicked = walled.piece?.occupied ?? []
check(kicked.allSatisfy { $0.x >= 0 && $0.x < GameState.columns },
      "rotating at the wall stays inside the board")

section("hard drop")
let dropper = GameState()
dropper.hardDrop()
let settledCount = dropper.locked.flatMap { $0 }.compactMap { $0 }.count
check(settledCount == 4, "exactly four cells settled")
check(dropper.piece != nil, "a new piece spawned after locking")
check(dropper.score > 0, "hard drop awards points")
check(dropper.activeCells.count == 4, "the new piece is intact")
check(dropper.locked[GameState.rows - 1].contains { $0 != nil }, "rests on the floor")

section("line clearing (pure)")
var oneFull = blankGrid()
oneFull[GameState.rows - 1] = fullRow()
let r1 = GameState.clearLines(in: oneFull)
check(r1.cleared == 1, "one completed row clears")
check(r1.grid.count == GameState.rows, "row count is preserved")
check(r1.grid[GameState.rows - 1].allSatisfy { $0 == nil }, "the cleared row is now empty")
check(r1.grid[GameState.rows - 2].allSatisfy { $0 == nil }, "grid shifted down cleanly")

var fourFull = blankGrid()
for row in (GameState.rows - 4)..<GameState.rows { fourFull[row] = fullRow() }
let r4 = GameState.clearLines(in: fourFull)
check(r4.cleared == 4, "four completed rows clear at once")
check(r4.grid.allSatisfy { row in row.allSatisfy { $0 == nil } }, "board is empty afterwards")

var noneFull = blankGrid()
noneFull[GameState.rows - 1][0] = .t
let r0 = GameState.clearLines(in: noneFull)
check(r0.cleared == 0, "an incomplete row does not clear")
check(r0.grid[GameState.rows - 1][0] == PieceType.t, "grid is untouched when nothing clears")

var mixed = blankGrid()
mixed[GameState.rows - 1] = fullRow()
mixed[GameState.rows - 2][3] = .l
let rm = GameState.clearLines(in: mixed)
check(rm.cleared == 1, "the full row cleared")
check(rm.grid[GameState.rows - 1][3] == PieceType.l, "the block above fell one row")

section("collision rules (pure)")
let empty = blankGrid()
let square = ActivePiece(type: .o, cells: PieceType.o.cells, origin: GridPoint(x: 3, y: 5))
check(!GameState.collides(square, with: empty), "free space is legal")

var leftOut = square
leftOut.origin = GridPoint(x: -2, y: 5)
check(GameState.collides(leftOut, with: empty), "past the left wall collides")

var rightOut = square
rightOut.origin = GridPoint(x: 9, y: 5)
check(GameState.collides(rightOut, with: empty), "past the right wall collides")

var belowFloor = square
belowFloor.origin = GridPoint(x: 3, y: GameState.rows)
check(GameState.collides(belowFloor, with: empty), "below the floor collides")

var settled = blankGrid()
settled[6][4] = .z
check(GameState.collides(square, with: settled), "overlapping a settled cell collides")

var aboveCeiling = square
aboveCeiling.origin = GridPoint(x: 3, y: -1)
check(!GameState.collides(aboveCeiling, with: empty), "above the ceiling is allowed")

section("scoring")
check(GameState.points(forLines: 1, level: 1) == 100, "single = 100")
check(GameState.points(forLines: 2, level: 1) == 300, "double = 300")
check(GameState.points(forLines: 3, level: 1) == 500, "triple = 500")
check(GameState.points(forLines: 4, level: 1) == 800, "tetris = 800")
check(GameState.points(forLines: 4, level: 3) == 2400, "scales with level")
check(GameState.points(forLines: 0, level: 5) == 0, "no lines, no points")

section("gravity")
let slow = GameState()
check(slow.gravityInterval > 0.7, "level 1 drops slowly")
check(slow.gravityInterval <= 0.8, "level 1 is not slower than the base rate")

section("ghost piece")
let ghosted = GameState()
let ghost = ghosted.ghostCells()
check(ghost.count == 4, "ghost covers four cells")
check(ghost.allSatisfy { $0.y >= 0 && $0.y < GameState.rows }, "ghost is on the board")
check(ghost.map { $0.y }.max() == GameState.rows - 1, "ghost lands on the floor on a fresh board")

// ─────────────────────────────────────────────────────────────────────────────
// A real game, played with a proper placement heuristic so that rows actually
// fill. This exercises locking, clearing and scoring together.

section("full game: placement integrity")

func slideFullyLeft(_ game: GameState) {
    var last = game.piece?.origin.x ?? 0
    for _ in 0..<30 {
        game.moveLeft()
        let now = game.piece?.origin.x ?? 0
        if now == last { break }
        last = now
    }
}

/// Classic Tetris heuristic: reward low stacks, punish holes and bumpiness.
func boardCost(_ grid: [[PieceType?]]) -> Int {
    var heights = [Int](repeating: 0, count: GameState.columns)
    var holes = 0

    for x in 0..<GameState.columns {
        var seenBlock = false
        for y in 0..<GameState.rows {
            if grid[y][x] != nil {
                // Height is measured to the TOP-most block, so only record
                // the first one encountered scanning downwards.
                if !seenBlock {
                    heights[x] = GameState.rows - y
                    seenBlock = true
                }
            } else if seenBlock {
                holes += 1
            }
        }
    }

    let aggregate = heights.reduce(0, +)
    var bumpiness = 0
    for x in 0..<(GameState.columns - 1) {
        bumpiness += abs(heights[x] - heights[x + 1])
    }
    return aggregate + holes * 8 + bumpiness * 2
}

/// Picks the rotation and column that leave the cheapest board, then moves the
/// piece into that position.
func placeWell(_ game: GameState) {
    guard game.piece != nil else { return }

    var bestRotations = 0
    var bestOffset = 0
    var bestCost = Int.max

    for rotation in 0..<4 {
        slideFullyLeft(game)

        var offset = 0
        var last = game.piece?.origin.x ?? 0

        while true {
            guard let current = game.piece else { break }
            let landing = game.ghostCells()

            if !landing.isEmpty, landing.allSatisfy({ $0.y >= 0 }) {
                var trial = game.locked
                for cell in landing { trial[cell.y][cell.x] = current.type }
                let cost = boardCost(trial)
                if cost < bestCost {
                    bestCost = cost
                    bestRotations = rotation
                    bestOffset = offset
                }
            }

            game.moveRight()
            let now = game.piece?.origin.x ?? 0
            if now == last { break }
            last = now
            offset += 1
        }

        slideFullyLeft(game)
        game.rotate()
    }

    for _ in 0..<bestRotations { game.rotate() }
    slideFullyLeft(game)
    for _ in 0..<bestOffset { game.moveRight() }
}

let mortal = GameState()
var drops = 0
var rowsLeftFull = 0
var shapeMismatches = 0
var cellCountMismatches = 0
var clearEvents = 0
var biggestClear = 0

while !mortal.isGameOver && drops < 1000 {
    let boardBefore = occupied(mortal.locked)
    let linesBefore = mortal.linesCleared

    placeWell(mortal)
    guard let placed = mortal.piece else { break }

    mortal.hardDrop()
    drops += 1

    let boardAfter = occupied(mortal.locked)

    if mortal.linesCleared == linesBefore {
        // Nothing shifted, so the newly added cells must be exactly the piece,
        // shifted straight down from where it was placed.
        let added = boardAfter.subtracting(boardBefore)
        if added.count != placed.cells.count {
            cellCountMismatches += 1
        }
        var matched = false
        for dy in 0..<GameState.rows {
            let shifted = Set(placed.occupied.map { GridPoint(x: $0.x, y: $0.y + dy) })
            if shifted == added { matched = true; break }
        }
        if !matched { shapeMismatches += 1 }
    } else {
        let cleared = mortal.linesCleared - linesBefore
        clearEvents += 1
        biggestClear = max(biggestClear, cleared)
        if cleared < 1 || cleared > 4 { cellCountMismatches += 1 }
    }

    if !mortal.isGameOver {
        for row in mortal.locked where !row.contains(where: { $0 == nil }) {
            rowsLeftFull += 1
        }
    }
}

print("   ..  played \(drops) pieces, cleared \(mortal.linesCleared) lines in \(clearEvents) events (max \(biggestClear)), score \(mortal.score), level \(mortal.level)")

check(shapeMismatches == 0, "every locked piece lands as one rigid shape")
check(cellCountMismatches == 0, "locked cells always match the piece size")
check(rowsLeftFull == 0, "no completed row is ever left on the board")
check(mortal.linesCleared > 20, "a competent player clears plenty of lines")
check(clearEvents > 0, "line clears happened during play")
check(biggestClear >= 1 && biggestClear <= 4, "clears never exceed four rows")
check(drops >= 1000, "a competent player survives a long game without topping out")
check(mortal.level == GameState.maxLevel, "level clamps at the maximum")
check(mortal.gravityInterval < 0.2, "gravity has sped up at the top level")
check(mortal.locked.count == GameState.rows, "still 20 rows after a full game")
check(mortal.locked.allSatisfy { $0.count == GameState.columns }, "still 10 columns per row")
check(mortal.score > 0, "score accumulated")
check(mortal.level >= 1 && mortal.level <= GameState.maxLevel, "level stays in range")

section("game over detection")

// Playing badly on purpose: stack every piece against the left wall.
let doomed = GameState()
var doomedDrops = 0
while !doomed.isGameOver && doomedDrops < 300 {
    slideFullyLeft(doomed)
    doomed.hardDrop()
    doomedDrops += 1
}

print("   ..  naive stacking topped out after \(doomedDrops) pieces")

check(doomed.isGameOver, "stacking one column tops the board out")
check(doomedDrops < 300, "the game does not run forever when played badly")
check(doomed.locked.count == GameState.rows, "grid is intact after game over")
check(doomed.locked.allSatisfy { $0.count == GameState.columns }, "columns intact after game over")
check(doomed.ghostCells().isEmpty, "no ghost is offered once the game is over")

let scoreAtEnd = doomed.score
doomed.hardDrop()
doomed.moveLeft()
doomed.rotate()
check(doomed.score == scoreAtEnd, "input after game over is ignored")

// A fresh game must fully recover.
doomed.startNewGame()
check(!doomed.isGameOver, "restart clears the game over flag")
check(doomed.locked.allSatisfy { row in row.allSatisfy { $0 == nil } }, "restart empties the board")
check(doomed.score == 0 && doomed.level == 1 && doomed.linesCleared == 0, "restart resets the score")

// ─────────────────────────────────────────────────────────────────────────────

print("\n────────────────────────────")
print("passed: \(passed)   failed: \(failed)")
if failed > 0 {
    print("RESULT: FAILURES")
    exit(1)
} else {
    print("RESULT: ALL PASSED")
    exit(0)
}
