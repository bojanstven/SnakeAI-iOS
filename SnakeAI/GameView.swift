import SwiftUI

struct Position: Equatable, Hashable {
    var x: Int
    var y: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
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
    @StateObject private var snakeAI = SnakeAI(level: .basic)
    @StateObject private var soundManager = SoundManager()


    @State private var isPaused = false
    @State private var score = 0
    @State private var snakePositions = [Position(x: 0, y: 0)]
    @State private var foodPosition = Position(x: 0, y: 0)
    @State private var direction = Direction.right
    @State private var isGameOver = false
    @State private var lastDirection = Direction.right
    
    @State private var wallsOn = false
    @State private var gamepadConnected = false
    @State private var autoplayEnabled = false
    @State private var settingsOpen = false
    @State private var isInitialized = false
    
    @State private var showSparkles = false
    @State private var sparkleOpacity: CGFloat = 0
    
    @State private var gameSpeed: Int = 2  // Default middle speed
    
    @Environment(\.scenePhase) private var scenePhase
    
    private let moveInterval: TimeInterval = 0.2
    private let frameWidth: CGFloat = 1
    
    private var borderStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: frameWidth,
            lineCap: .round,
            lineJoin: .round,
            dash: wallsOn ? [] : [2, 5],
            dashPhase: 0
        )
    }
    
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
        gameLoop.stop()
        isGameOver = false
        isPaused = false
        
        score = 0
        direction = .right
        lastDirection = .right
        
        let startX = layout.maxX / 2
        let startY = layout.maxY / 2
        
        snakePositions = [
            Position(x: startX, y: startY),
            Position(x: startX - 1, y: startY),
            Position(x: startX - 2, y: startY)
        ]
        
        generateNewFoodPosition(maxX: layout.maxX, maxY: layout.maxY)
        print("🐍 New game started! Grid size: \(layout.maxX)x\(layout.maxY)")

        gameLoop.frameCallback = { [self] in
            moveSnake(maxX: layout.maxX, maxY: layout.maxY)
        }
        gameLoop.start()
        scoreManager.startNewGame(isAIEnabled: autoplayEnabled)
    }
    
    private func forceImmediateMove(maxX: Int, maxY: Int) {
        moveSnake(maxX: maxX, maxY: maxY)
        print("🐍 Forced immediate move in direction: \(direction)")
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
        
        if autoplayEnabled {
            direction = snakeAI.calculateNextMove(
                snake: snakePositions,
                food: foodPosition,
                boardSize: (width: maxX, height: maxY),
                wallsOn: wallsOn
            )
        }
        
        switch direction {
        case .up: newHead.y -= 1
        case .down: newHead.y += 1
        case .left: newHead.x -= 1
        case .right: newHead.x += 1
        case .none: return
        }
        
        if newHead.x < 0 || newHead.x >= maxX || newHead.y < 0 || newHead.y >= maxY {
            if !wallsOn {
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
            } else {
                endGame()
                return
            }
        }

        if snakePositions.contains(newHead) {
            endGame()
            return
        }
        
        snakePositions.insert(newHead, at: 0)
        lastDirection = direction
        
        if newHead == foodPosition {
            let newScore = score + 1
            scoreManager.updateScores(newScore: newScore)
            score = newScore
            hapticsManager.foodEatenHaptic()
            
            if newScore > scoreManager.highScore {
                soundManager.playGameOver()
                showSparkles = true
                sparkleOpacity = 1
                withAnimation(.easeOut(duration: 1.5)) {
                    sparkleOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSparkles = false
                }
            } else {
                soundManager.playEatFood()
            }

            generateNewFoodPosition(maxX: maxX, maxY: maxY)
            print("🐍 Food eaten: \(newScore), Total length: \(snakePositions.count + 1)")
        } else {
            snakePositions.removeLast()
        }
    }
    
    private func togglePause(maxX: Int, maxY: Int) {
        isPaused = !isPaused
        if isPaused {
            gameLoop.stop()
            soundManager.playGamePause()
        } else {
            gameLoop.start()
            soundManager.playGameUnpause()
        }
    }
    
    private func endGame() {
        gameLoop.stop()
        isGameOver = true
        hapticsManager.gameOverHaptic()
        soundManager.playGameOver()
        scoreManager.endGame()
        print("🐍 Game Over! Final Score: \(score)")
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
            
            ZStack {
                Color(red: 0.65, green: 0.75, blue: 0.65)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    HStack(spacing: geometry.size.width * 0.02) {
                        // High Score (on the left)
                        AnimatedScoreView(
                            score: scoreManager.highScore,
                            isHighScore: true
                        )
                        .frame(maxHeight: .infinity)  // Fill the available height
                        
                        Spacer()
                        
                        // Current Score (on the right)
                        Text("\(score)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.0))
                    }
                    .frame(height: geometry.size.height * 0.03)  // Set the container height
                    .padding(.horizontal, geometry.size.width * 0.02)
                    .padding(.bottom, geometry.size.height * 0.007)  // Consistent bottom margin for both scores

                    ZStack {
                        Rectangle()
                            .fill(Color(red: 0.60, green: 0.70, blue: 0.60))
                        
                        GeometryReader { proxy in
                            let columns = Int(proxy.size.width / layout.squareSize)
                            let rows = Int(proxy.size.height / layout.squareSize)
                            
                            ForEach(0..<rows, id: \.self) { row in
                                ForEach(0..<columns, id: \.self) { column in
                                    if (row + column).isMultiple(of: 2) {
                                        Rectangle()
                                            .fill(Color(red: 0.58, green: 0.68, blue: 0.58))
                                            .frame(width: layout.squareSize, height: layout.squareSize)
                                            .position(
                                                x: CGFloat(column) * layout.squareSize + layout.squareSize/2,
                                                y: CGFloat(row) * layout.squareSize + layout.squareSize/2
                                            )
                                    }
                                }
                            }
                        }
                        
                        Rectangle()
                            .stroke(
                                Color(red: 0.0, green: 0.1, blue: 0.0),
                                style: borderStyle
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
                        
                        if showSparkles {
                            SparkleView()
                                .opacity(sparkleOpacity)
                                .allowsHitTesting(false)
                        }
                        
                        if isGameOver {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .blur(radius: 3)
                                .ignoresSafeArea()
                            
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
                        
                        if isPaused && !isGameOver {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .blur(radius: 3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 20) {
                                Text("Game Paused")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.2))
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
                                print("🐍 Swipe detected!")
                                if !isPaused && !isGameOver && !autoplayEnabled {
                                    let horizontalAmount = gesture.translation.width
                                    let verticalAmount = gesture.translation.height
                                    
                                    print("🐍 Swipe amounts - H: \(horizontalAmount), V: \(verticalAmount)")
                                    print("🐍 Current direction: \(direction)")
                                    
                                    if abs(horizontalAmount) > abs(verticalAmount) {
                                        let newDirection = horizontalAmount > 0 ? Direction.right : Direction.left
                                        print("🐍 New horizontal direction: \(newDirection)")
                                        
                                        if newDirection == direction {
                                            print("🐍 Same direction swipe!")
                                            moveSnake(maxX: layout.maxX, maxY: layout.maxY)
                                        } else if newDirection != direction.opposite && newDirection != lastDirection.opposite {
                                            direction = newDirection
                                        }
                                    } else {
                                        let newDirection = verticalAmount > 0 ? Direction.down : Direction.up
                                        print("🐍 New vertical direction: \(newDirection)")
                                        
                                        if newDirection == direction {
                                            print("🐍 Same direction swipe!")
                                            moveSnake(maxX: layout.maxX, maxY: layout.maxY)
                                        } else if newDirection != direction.opposite && newDirection != lastDirection.opposite {
                                            direction = newDirection
                                        }
                                    }
                                } else {
                                    print("🐍 Game state prevented move - Paused: \(isPaused), GameOver: \(isGameOver), Autoplay: \(autoplayEnabled)")
                                }
                            }
                    )
                    
                    .gesture(  // Change this to regular gesture instead of SpatialTapGesture
                        TapGesture()
                            .onEnded { _ in
                                if !isGameOver && !settingsOpen {  // Add settingsOpen check
                                    togglePause(maxX: layout.maxX, maxY: layout.maxY)
                                }
                            }
                    )

                    HStack(spacing: geometry.size.width * 0.02) {  // Reduced spacing between buttons
                        // Walls toggle
                        Button(action: {
                            hapticsManager.toggleHaptic()
                            DispatchQueue.main.async {
                                wallsOn.toggle()
                                if wallsOn {
                                    soundManager.playWallSwitchOn()
                                } else {
                                    soundManager.playWallSwitchOff()
                                }
                                print("🐍 Walls \(wallsOn ? "On" : "Off")")
                            }
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: !wallsOn ? "shield.lefthalf.filled.slash" : "shield.lefthalf.filled")
                                    .font(.title2)
                                Text("Walls")
                                    .font(.system(size: 20, weight: .medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: buttonSize)
                            .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                            .foregroundColor(!wallsOn ? .white : .black)  // White when walls are off (pass through)
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
                            if autoplayEnabled {
                                soundManager.playAutoplayOn()
                                print("🐍 AI Control activated")
                            } else {
                                soundManager.playAutoplayOff()
                                print("🐍 Manual Control restored")
                            }
                        }) {
                            HStack(spacing: 2) {  // Minimal spacing between icon and text
                                Image(systemName: "brain.filled.head.profile")
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
                            if settingsOpen {
                                // Store current state and pause
                                gameLoop.stop()
                                isPaused = true
                            } else {
                                // Resume game
                                gameLoop.start()
                                isPaused = false
                            }
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
                
                if settingsOpen {
                    SettingsView(
                        isOpen: $settingsOpen,
                        wallsOn: $wallsOn,
                        autoplayEnabled: $autoplayEnabled,
                        snakeAI: snakeAI,
                        hapticsManager: hapticsManager,
                        isPaused: $isPaused,
                        isGameOver: $isGameOver,
                        gameLoop: gameLoop,
                        gameSpeed: $gameSpeed,
                        scoreManager: scoreManager
                    )
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
            .onChange(of: scenePhase, initial: false) { oldPhase, newPhase in
                switch newPhase {
                case .active:
                    print("🐍 App became active")
                    // Don't auto-resume, let user decide
                case .inactive:
                    print("🐍 App became inactive")
                    if !isPaused && !isGameOver {
                        // Optional: Pause on partial hide when in manual mode
                        if !autoplayEnabled {
                            togglePause(maxX: layout.maxX, maxY: layout.maxY)
                        }
                    }
                case .background:
                    print("🐍 App entered background")
                    if !isPaused && !isGameOver {
                        togglePause(maxX: layout.maxX, maxY: layout.maxY)
                    }
                @unknown default:
                    print("🐍 Unknown scene phase")
                }
            }
        }
    }
}

#Preview {
    GameView()
}
