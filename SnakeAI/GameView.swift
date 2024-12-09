import SwiftUI

struct Position: Equatable {
    var x: Int
    var y: Int
}

enum Direction {
    case up, down, left, right, none
    
    var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        case .none: return .none
        }
    }
}

struct GameView: View {
    @StateObject private var hapticsManager = HapticsManager()
    @StateObject private var scoreManager = ScoreManager()
    @StateObject private var gameLoop = GameLoop()
    @State private var isPaused = false
    @State private var score = 0
    @State private var snakePositions = [Position(x: 0, y: 0)]
    @State private var foodPosition = Position(x: 0, y: 0)
    @State private var direction = Direction.right
    @State private var isGameOver = false
    @State private var lastDirection = Direction.right
    
    @State private var wallsEnabled = false
    @State private var gamepadConnected = false
    @State private var autoplayEnabled = false
    @State private var settingsOpen = false
    @State private var isInitialized = false
    
    private let moveInterval: TimeInterval = 0.2
    private let frameWidth: CGFloat = 1
    
    private func calculateLayout(for geometry: GeometryProxy) -> (squareSize: CGFloat, gameHeight: CGFloat, maxX: Int, maxY: Int) {
        let sideMargin = geometry.size.width * 0.02
        let topMargin = geometry.size.height * 0.03
        let bottomMargin = geometry.size.height * 0.10
        
        let gameWidth = geometry.size.width - (sideMargin * 2)
        let gameHeight = geometry.size.height - (topMargin + bottomMargin)
        
        let idealSquareCount: CGFloat = 20
        let squareSize = gameWidth / idealSquareCount
        
        let maxX = Int(floor(gameWidth / squareSize))
        let maxY = Int(floor(gameHeight / squareSize))
        
        return (squareSize, gameHeight, maxX, maxY)
    }
    
    private func startGame(with layout: (squareSize: CGFloat, gameHeight: CGFloat, maxX: Int, maxY: Int)) {
        score = 0
        isGameOver = false
        direction = .right
        lastDirection = .right
        isPaused = false
        
        let startX = layout.maxX / 2
        let startY = layout.maxY / 2
        
        snakePositions = [
            Position(x: startX, y: startY),
            Position(x: startX - 1, y: startY),
            Position(x: startX - 2, y: startY)
        ]
        
        generateNewFoodPosition(maxX: layout.maxX, maxY: layout.maxY)
        print("New game started! Grid size: \(layout.maxX)x\(layout.maxY)")
        
        // Set up game loop
        gameLoop.frameCallback = { [self] in
            moveSnake(maxX: layout.maxX, maxY: layout.maxY)
        }
        gameLoop.start()
    }
    
    private func generateNewFoodPosition(maxX: Int, maxY: Int) {
        repeat {
            foodPosition = Position(
                x: Int.random(in: 0..<maxX),
                y: Int.random(in: 0..<maxY)
            )
        } while snakePositions.contains(foodPosition)
    }
    
    private func moveSnake(maxX: Int, maxY: Int) {
        guard var newHead = snakePositions.first else { return }
        
        switch direction {
        case .up: newHead.y -= 1
        case .down: newHead.y += 1
        case .left: newHead.x -= 1
        case .right: newHead.x += 1
        case .none: return
        }
        
        // For moveSnake function
        if newHead.x < 0 || newHead.x >= maxX || newHead.y < 0 || newHead.y >= maxY {
            if !wallsEnabled {  // When walls button is OFF (black), die
                endGame()
                return
            } else {  // When walls button is ON (white), teleport
                // Wrap around logic
                if newHead.x < 0 {
                    newHead.x = maxX - 1
                } else if newHead.x >= maxX {
                    newHead.x = 0
                }
                if newHead.y < 0 {
                    newHead.y = maxY - 1
                } else if newHead.y >= maxY {
                    newHead.y = 0
                }
            }
        }
        // Check self collision
        if snakePositions.contains(newHead) {
            endGame()
            return
        }
        
        snakePositions.insert(newHead, at: 0)
        lastDirection = direction
        
        if newHead == foodPosition {
            scoreManager.updateScores(newScore: score + 1)
            score = score + 1
            hapticsManager.foodEatenHaptic()
            generateNewFoodPosition(maxX: maxX, maxY: maxY)
            print("Snake grew! New length: \(snakePositions.count + 1)")
        } else {
            snakePositions.removeLast()
        }
    }
    
    private func togglePause(maxX: Int, maxY: Int) {
        isPaused = !isPaused
        if isPaused {
            gameLoop.stop()
        } else {
            gameLoop.start()
        }
    }
    
    private func endGame() {
        gameLoop.stop()
        isGameOver = true
        hapticsManager.gameOverHaptic()
        print("Game Over! Final Score: \(score)")
    }
    
    private func tryChangeDirection(_ newDirection: Direction) {
        if newDirection != direction.opposite && newDirection != lastDirection.opposite {
            direction = newDirection
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let layout = calculateLayout(for: geometry)
            let buttonSize = min(geometry.size.width * 0.15, 50.0)
            
            ZStack {  // MARK: - Root ZStack: Main container for background and entire game layout
                Color(red: 0.65, green: 0.75, blue: 0.65)  // Main background color
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    HStack(spacing: geometry.size.width * 0.02) {
                        Image(systemName: "crown.fill")
                            .font(.title)
                            .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.0))
                        
                        Text("Score: \(score)")
                            .font(.title)
                            .bold()
                            .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.0))
                        
                        Spacer()
                        
                        Text("Best: \(scoreManager.highScore)")
                            .font(.title)
                            .bold()
                            .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.0))
                    }
                    .frame(height: geometry.size.height * 0.03)
                    .padding(.horizontal, geometry.size.width * 0.02)
                    .padding(.bottom, geometry.size.height * 0.007)

                    ZStack {  // MARK: - Game Area ZStack: Contains game board, snake, food, and overlays
                        // This is where we want to add the checkerboard pattern
                        
                        // Base darker green
                        Rectangle()
                            .fill(Color(red: 0.60, green: 0.70, blue: 0.60))
                        
                        // Checkerboard pattern
                        GeometryReader { proxy in
                            let columns = Int(proxy.size.width / layout.squareSize)
                            let rows = Int(proxy.size.height / layout.squareSize)
                            
                            ForEach(0..<rows, id: \.self) { row in
                                ForEach(0..<columns, id: \.self) { column in
                                    if (row + column).isMultiple(of: 2) {
                                        Rectangle()
                                            .fill(Color(red: 0.58, green: 0.68, blue: 0.58))  // Slightly darker shade
                                            .frame(width: layout.squareSize, height: layout.squareSize)
                                            .position(
                                                x: CGFloat(column) * layout.squareSize + layout.squareSize/2,
                                                y: CGFloat(row) * layout.squareSize + layout.squareSize/2
                                            )
                                    }
                                }
                            }
                        }
                        
                        // Border

                        Rectangle()
                            .stroke(
                                Color(red: 0.0, green: 0.1, blue: 0.0),
                                style: StrokeStyle(
                                    lineWidth: frameWidth,
                                    lineCap: .round,
                                    lineJoin: .round,
                                    dash: wallsEnabled ? [2, 5] : [],  // Dotted when walls button is ON (white), solid when OFF (black)
                                    dashPhase: 0
                                )
                            )
                        ForEach(0..<snakePositions.count, id: \.self) { index in
                            Rectangle()
                                .fill(index == 0
                                    ? Color(red: 0.0, green: 0.3, blue: 0.0)
                                    : Color(red: 0.0, green: 0.5, blue: 0.0)
                                )
                                .frame(
                                    width: layout.squareSize - 1,
                                    height: layout.squareSize - 1
                                )
                                .position(
                                    x: CGFloat(snakePositions[index].x) * layout.squareSize + layout.squareSize/2,
                                    y: CGFloat(snakePositions[index].y) * layout.squareSize + layout.squareSize/2
                                )
                        }
                        
                        Rectangle()
                            .fill(Color(red: 0.8, green: 0.0, blue: 0.0))
                            .frame(
                                width: layout.squareSize - 1,
                                height: layout.squareSize - 1
                            )
                            .position(
                                x: CGFloat(foodPosition.x) * layout.squareSize + layout.squareSize/2,
                                y: CGFloat(foodPosition.y) * layout.squareSize + layout.squareSize/2
                            )
                        
                        if isGameOver {
                            VStack(spacing: 20) {
                                Text("You Died!")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.red)
                                    .transition(.scale)
                                
                                Button(action: { startGame(with: layout) }) {
                                    Text("Restart")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 10)
                                        .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                                        .cornerRadius(10)
                                }
                            }
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.5), value: isGameOver)
                        }
                        
                        if isPaused {
                            VStack(spacing: 20) {
                                Text("Game Paused")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.0))
                                    .transition(.scale)
                                
                                Button(action: { togglePause(maxX: layout.maxX, maxY: layout.maxY) }) {
                                    Text("Resume")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 10)
                                        .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                                        .cornerRadius(10)
                                }
                            }
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.5), value: isPaused)
                        }
                    }
                    .frame(
                        width: geometry.size.width - (geometry.size.width * 0.02 * 2),
                        height: geometry.size.height - (geometry.size.height * 0.13)
                    )
                    .padding(.horizontal, geometry.size.width * 0.02)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { gesture in
                                if !isPaused && !isGameOver {
                                    let horizontalAmount = gesture.translation.width
                                    let verticalAmount = gesture.translation.height
                                    
                                    if abs(horizontalAmount) > abs(verticalAmount) {
                                        let newDirection = horizontalAmount > 0 ? Direction.right : Direction.left
                                        if newDirection != direction.opposite && newDirection != lastDirection.opposite {
                                            direction = newDirection
                                        }
                                    } else {
                                        let newDirection = verticalAmount > 0 ? Direction.down : Direction.up
                                        if newDirection != direction.opposite && newDirection != lastDirection.opposite {
                                            direction = newDirection
                                        }
                                    }
                                }
                            }
                    )

                    .gesture(
                        SpatialTapGesture(count: 1)
                            .simultaneously(with: SpatialTapGesture(count: 1))
                            .onEnded { _ in
                                if !isGameOver {
                                    togglePause(maxX: layout.maxX, maxY: layout.maxY)
                                }
                            }
                    )
                    
                    HStack(spacing: geometry.size.width * 0.02) {  // Reduced spacing between buttons
                        // Walls toggle
                        Button(action: {
                            wallsEnabled.toggle()
                            hapticsManager.toggleHaptic()
                            print("Walls \(wallsEnabled ? "enabled" : "disabled")")
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: wallsEnabled ? "shield.lefthalf.filled.slash" : "shield.lefthalf.filled")
                                    .font(.title2)
                                Text("Walls")
                                    .font(.system(size: 20, weight: .medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: buttonSize)
                            .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                            .foregroundColor(wallsEnabled ? .white : .black)  // Now black by default, white when enabled
                            .cornerRadius(8)
                        }

                        // Gamepad status - icon only
                        Button(action: {}) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.title2)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                                .foregroundColor(gamepadConnected ? .white : .black)
                                .cornerRadius(8)
                        }
                        .disabled(true)
                        
                        // Autoplay toggle
                        Button(action: {
                            autoplayEnabled.toggle()
                            hapticsManager.toggleHaptic()
                        }) {
                            HStack(spacing: 2) {  // Minimal spacing between icon and text
                                Image(systemName: "hands.and.sparkles.fill")
                                    .font(.title2)
                                Text("Auto")
                                    .font(.system(size: 20, weight: .medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)  // Fill available space
                            .frame(height: buttonSize)
                            .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                            .foregroundColor(autoplayEnabled ? .white : .black)
                            .cornerRadius(8)
                        }
                        
                        // Settings toggle
                        Button(action: {
                            settingsOpen.toggle()
                            hapticsManager.toggleHaptic()
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                                .foregroundColor(settingsOpen ? .white : .black)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, geometry.size.width * 0.02)  // Minimal padding at edges
                    .padding(.vertical, geometry.size.height * 0.01)   // Minimal vertical padding
                }
            }
            .onAppear {
                startGame(with: layout)
            }
            .task {
                if !isInitialized {
                    await scoreManager.fetchScores()
                    isInitialized = true
                }
            }
        }
    }
}

#Preview {
    GameView()
}
