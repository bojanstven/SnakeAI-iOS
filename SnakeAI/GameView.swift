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
    @State private var autoplayEnabled = false
    @State private var settingsOpen = false
    @State private var isInitialized = false
    @State private var isSoundEnabled = true
    
    
    @State private var gameSpeed: Int = 2  // Default middle speed
    
    @Environment(\.scenePhase) private var scenePhase
    
    private let moveInterval: TimeInterval = 0.2
    
    @State private var powerUpsEnabled = true
    @State private var enabledPowerUps: Set<PowerUpType> = Set(PowerUpType.allCases.filter { $0 != .slow })
    @State private var powerUpFoods: [PowerUpFood] = []
    @State private var activePowerUps: [ActivePowerUp] = []
    
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets
        }
        return .zero
    }

    
    private func calculateLayout(for geometry: GeometryProxy) -> (squareSize: CGFloat, gameHeight: CGFloat, maxX: Int, maxY: Int) {
        // Get the safe area insets
        let safeAreaInsets = getSafeAreaInsets()
        
        // Get total screen dimensions
        let totalWidth = geometry.size.width
        let totalHeight = geometry.size.height + safeAreaInsets.top + safeAreaInsets.bottom
        
        // We want at least 20 columns, calculate ideal square size
        let idealSquareSize = min(totalWidth / 20, totalHeight / 44)
        
        // Calculate actual number of squares that will fit perfectly
        let columns = Int(floor(totalWidth / idealSquareSize))
        let rows = Int(floor(totalHeight / idealSquareSize))
        
        // Recalculate square size to fill screen perfectly
        let squareSize = min(totalWidth / CGFloat(columns), totalHeight / CGFloat(rows))
                
        return (
            squareSize: squareSize,
            gameHeight: totalHeight,
            maxX: columns,
            maxY: rows

        )
        }

    
    private func startGame(with layout: (squareSize: CGFloat, gameHeight: CGFloat, maxX: Int, maxY: Int)) {
        // Print debug info only when game starts
        print("🐍 DEBUG: Layout Calculations")
        print("Total Height: \(layout.gameHeight)")
        print("Square Size: \(layout.squareSize)")
        print("Grid: \(layout.maxX)x\(layout.maxY)")
        print("🐍 New game started! Grid size: \(layout.maxX)x\(layout.maxY)")

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


        generateNewFoodPosition(maxX: layout.maxX, maxY: layout.maxY, squareSize: layout.squareSize)
        
        gameLoop.frameCallback = { [self] in
            moveSnake(maxX: layout.maxX, maxY: layout.maxY, squareSize: layout.squareSize)
        }
        gameLoop.start()
        scoreManager.startNewGame(isAIEnabled: autoplayEnabled)
    }
    
    private func forceImmediateMove(maxX: Int, maxY: Int, squareSize: CGFloat) {
        moveSnake(maxX: maxX, maxY: maxY, squareSize: squareSize)
        print("🐍 Forced immediate move in direction: \(direction)")
    }
    
    
    private func baseIntervalForGameSpeed(_ speed: Int) -> TimeInterval {
        let intervals: [TimeInterval] = [0.3, 0.25, 0.2, 0.15, 0.1]  // From slowest to fastest
        return intervals[speed]
    }
    
    
    private func generateNewFoodPosition(maxX: Int, maxY: Int, squareSize: CGFloat) {
        // Get Dynamic Island area to avoid
        let safeAreaInsets = getSafeAreaInsets()
        let topSafeRows = Int(ceil(safeAreaInsets.top / squareSize))
        
        repeat {
            foodPosition = Position(
                x: Int.random(in: 0..<maxX),
                y: Int.random(in: topSafeRows..<maxY)  // Start after Dynamic Island
            )
        } while snakePositions.contains(foodPosition) ||
        powerUpFoods.contains(where: { $0.position == foodPosition })

        // Power-up generation
        if powerUpsEnabled && !enabledPowerUps.isEmpty {
            // 20% chance to spawn a power-up
            if Double.random(in: 0...1) < 0.2 {
                let availablePowerUps = Array(enabledPowerUps)
                let randomPowerUp = availablePowerUps.randomElement()!
                
                var newPowerUpPosition: Position
                repeat {
                    newPowerUpPosition = Position(
                        x: Int.random(in: 0..<maxX),
                        y: Int.random(in: topSafeRows..<maxY)  // Also avoid Dynamic Island for power-ups
                    )
                } while snakePositions.contains(newPowerUpPosition) ||
                powerUpFoods.contains(where: { $0.position == newPowerUpPosition }) ||
                newPowerUpPosition == foodPosition
                
                powerUpFoods.append(PowerUpFood(
                    position: newPowerUpPosition,
                    type: randomPowerUp,
                    createdAt: Date()
                ))
                
                print("🐍 Power-up spawned: \(randomPowerUp.rawValue) at position: (\(newPowerUpPosition.x), \(newPowerUpPosition.y))")
            }
        }
    }
    
    
    private func moveSnake(maxX: Int, maxY: Int, squareSize: CGFloat) {
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
        
        // Check for power-up collection
        if let powerUpIndex = powerUpFoods.firstIndex(where: { $0.position == newHead }) {
            let powerUp = powerUpFoods[powerUpIndex]
            powerUpFoods.remove(at: powerUpIndex)
            
            activePowerUps.append(ActivePowerUp(
                type: powerUp.type,
                expiresAt: Date().addingTimeInterval(powerUp.type.duration)
            ))
            
            print("🐍 Power-up collected: \(powerUp.type.rawValue)")
            print("🐍 Power-up duration: \(powerUp.type.duration)s")
            
            hapticsManager.foodEatenHaptic()
            soundManager.playEatFood()
        }
        
        // Regular food collection
        if newHead == foodPosition {
            let basePoints = 1
            let pointMultiplier = activePowerUps.first(where: { $0.type == .golden })?.type.scoreMultiplier ?? 1
            let newScore = score + (basePoints * pointMultiplier)
            
            scoreManager.updateScores(newScore: newScore)
            score = newScore
            hapticsManager.foodEatenHaptic()
            
            if newScore > scoreManager.highScore {
                soundManager.playGameOver()
            } else {
                soundManager.playEatFood()
            }
            
            generateNewFoodPosition(maxX: maxX, maxY: maxY, squareSize: squareSize)
            print("🐍 Food eaten: \(newScore), Total length: \(snakePositions.count + 1)")
            
            if pointMultiplier > 1 {
                print("🐍 Score multiplier active: \(pointMultiplier)x")
            }
        } else {
            snakePositions.removeLast()
        }
        
        // Update game speed based on active power-ups
        let baseInterval = baseIntervalForGameSpeed(gameSpeed)  // Use slider speed as base
        if let speedPowerUp = activePowerUps.first(where: { $0.type == .speed }) {
            gameLoop.updateInterval = baseInterval / 2
            print("🐍 Speed boost active: \(speedPowerUp.remainingTime)s remaining")
        } else if let slowPowerUp = activePowerUps.first(where: { $0.type == .slow }) {
            gameLoop.updateInterval = baseInterval * 2
            print("🐍 Speed reduction active: \(slowPowerUp.remainingTime)s remaining")
        } else {
            gameLoop.updateInterval = baseInterval
        }
        
        // Clean up expired power-ups
        let expiredCount = activePowerUps.filter({ $0.isExpired }).count
        if expiredCount > 0 {
            print("🐍 \(expiredCount) power-up(s) expired")
        }
        activePowerUps.removeAll(where: { $0.isExpired })
        powerUpFoods.removeAll(where: { $0.isExpired })
    }
    
    
    private func toggleSound() {
        isSoundEnabled.toggle()
        if isSoundEnabled {
            // Re-enable sounds
            soundManager.setVolume(1.0)
        } else {
            // Mute sounds
            soundManager.setVolume(0.0)
        }
        hapticsManager.toggleHaptic()
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
    
    
    private func handleSwipe(gesture: DragGesture.Value, maxX: Int, maxY: Int, squareSize: CGFloat) {
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
                    forceImmediateMove(maxX: maxX, maxY: maxY, squareSize: squareSize)
                } else if newDirection != direction.opposite && newDirection != lastDirection.opposite {
                    direction = newDirection
                }
            } else {
                let newDirection = verticalAmount > 0 ? Direction.down : Direction.up
                print("🐍 New vertical direction: \(newDirection)")
                
                if newDirection == direction {
                    print("🐍 Same direction swipe!")
                    forceImmediateMove(maxX: maxX, maxY: maxY, squareSize: squareSize)
                } else if newDirection != direction.opposite && newDirection != lastDirection.opposite {
                    direction = newDirection
                }
            }
        } else {
            print("🐍 Game state prevented move - Paused: \(isPaused), GameOver: \(isGameOver), Autoplay: \(autoplayEnabled)")
        }
    }
    
    
    
    var body: some View {
        GeometryReader { geometry in
            let layout = calculateLayout(for: geometry)
            let buttonSize = min(geometry.size.width * 0.15, 50.0)
            
            ZStack {
                // Background color
                Color(red: 0.55, green: 0.65, blue: 0.55)
                    .ignoresSafeArea()

                // Game grid
                GeometryReader { proxy in
                    ForEach(0..<layout.maxY, id: \.self) { row in
                        ForEach(0..<layout.maxX, id: \.self) { column in
                            if (row + column).isMultiple(of: 2) {
                                Rectangle()
                                    .fill(Color(red: 0.51, green: 0.61, blue: 0.51))
                                    .frame(
                                        width: layout.squareSize,
                                        height: layout.squareSize
                                    )
                                    .position(
                                        x: layout.squareSize * (CGFloat(column) + 0.5),
                                        y: layout.squareSize * (CGFloat(row) + 0.5)
                                    )
                            }
                        }
                    }
                }
                .ignoresSafeArea()

                    
                // 4. Snake (now rendered last/on top)
                GeometryReader { proxy in
                    ForEach(0..<snakePositions.count, id: \.self) { index in
                        Rectangle()
                            .fill(index == 0
                                  ? Color(red: 0.0, green: 0.3, blue: 0.0)  // Head color
                                  : Color(red: 0.0, green: 0.5, blue: 0.0)  // Body color
                            )
                            .frame(
                                width: layout.squareSize - 1,
                                height: layout.squareSize - 1
                            )
                            .position(
                                x: layout.squareSize * (CGFloat(snakePositions[index].x) + 0.5),
                                y: layout.squareSize * (CGFloat(snakePositions[index].y) + 0.5)
                            )
                    }
                }
                .ignoresSafeArea()

                
                // 3. Food and Power-ups
                GeometryReader { proxy in
                    // Regular food
                    Rectangle()
                        .fill(Color(red: 0.8, green: 0.0, blue: 0.0))
                        .frame(
                            width: layout.squareSize - 1,
                            height: layout.squareSize - 1
                        )
                        .position(
                            x: layout.squareSize * (CGFloat(foodPosition.x) + 0.5),
                            y: layout.squareSize * (CGFloat(foodPosition.y) + 0.5)
                        )
                    
                    // Power-up foods
                    ForEach(powerUpFoods, id: \.position) { powerUp in
                        PowerUpFoodView(powerUp: powerUp, size: layout.squareSize)
                            .position(
                                x: layout.squareSize * (CGFloat(powerUp.position.x) + 0.5),
                                y: layout.squareSize * (CGFloat(powerUp.position.y) + 0.5)
                            )
                    }
                }
                .ignoresSafeArea()

                
                // Score header
                ScoreHeader(
                    geometry: geometry,
                    score: score,
                    highScore: scoreManager.highScore
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Power-up indicators
                VStack {
                    ForEach(activePowerUps, id: \.expiresAt) { powerUp in
                        ActivePowerUpIndicator(powerUp: powerUp)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding()
                
                // Game Over overlay
                if isGameOver {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .blur(radius: 3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Text("Game Over!")
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
                
                // Pause overlay
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
                
                // Control buttons
                GameControlButtons(
                    buttonSize: buttonSize,
                    wallsOn: $wallsOn,
                    autoplayEnabled: $autoplayEnabled,
                    settingsOpen: $settingsOpen,
                    isPaused: $isPaused,
                    isSoundEnabled: $isSoundEnabled,
                    hapticsManager: hapticsManager,
                    soundManager: soundManager
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    if !isPaused && !isGameOver {
                        togglePause(maxX: layout.maxX, maxY: layout.maxY)
                    }
                }
            }
            .sheet(isPresented: $settingsOpen) {
                SettingsView(
                    isOpen: $settingsOpen,
                    wallsOn: $wallsOn,
                    autoplayEnabled: $autoplayEnabled,
                    isSoundEnabled: $isSoundEnabled,
                    snakeAI: snakeAI,
                    hapticsManager: hapticsManager,
                    isPaused: $isPaused,
                    isGameOver: $isGameOver,
                    gameLoop: gameLoop,
                    gameSpeed: $gameSpeed,
                    scoreManager: scoreManager,
                    powerUpsEnabled: $powerUpsEnabled,
                    enabledPowerUps: $enabledPowerUps,
                    baseIntervalForGameSpeed: baseIntervalForGameSpeed
                )
            }

            
            
            .onAppear {
                print("🐍 DEBUG: View appeared")
                startGame(with: layout)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { gesture in
                        handleSwipe(gesture: gesture, maxX: layout.maxX, maxY: layout.maxY, squareSize: layout.squareSize)
                    }
            )
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        if !isGameOver && !settingsOpen {
                            togglePause(maxX: layout.maxX, maxY: layout.maxY)
                            
                        }
                    }
            )
        }
    }
    
    
    
    
}
    
    
struct GameControlButtons: View {
    let buttonSize: CGFloat
    let wallsOn: Binding<Bool>
    let autoplayEnabled: Binding<Bool>
    let settingsOpen: Binding<Bool>
    let isPaused: Binding<Bool>
    let isSoundEnabled: Binding<Bool>
    let hapticsManager: HapticsManager
    let soundManager: SoundManager
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                hapticsManager.toggleHaptic()
                isSoundEnabled.wrappedValue.toggle()
                if isSoundEnabled.wrappedValue {
                    soundManager.setVolume(1.0)
                } else {
                    soundManager.setVolume(0.0)
                }
            }) {
                Image(systemName: isSoundEnabled.wrappedValue ? "bell.fill" : "bell.slash.fill")
                    .font(.system(size: 37))
                    .foregroundColor(isSoundEnabled.wrappedValue ? .white : .black)
                    .frame(width: 50, height: 50)
                    .frame(minWidth: 50, minHeight: 50)
                    .clipShape(Circle())
            }
            
            Button(action: {
                hapticsManager.toggleHaptic()
                wallsOn.wrappedValue.toggle()
                if wallsOn.wrappedValue {
                    soundManager.playWallSwitchOn()
                } else {
                    soundManager.playWallSwitchOff()
                }
            }) {
                Image(systemName: !wallsOn.wrappedValue ? "firewall.fill" : "shield.slash.fill")
                    .font(.system(size: 37))
                    .foregroundColor(!wallsOn.wrappedValue ? .white : .black)
                    .frame(width: 50, height: 50)
                    .frame(minWidth: 50, minHeight: 50)  // Minimum touch target size
                    .clipShape(Circle())  // Make the touch target circular
            }
            
            Button(action: {
                autoplayEnabled.wrappedValue.toggle()
                hapticsManager.toggleHaptic()
                if autoplayEnabled.wrappedValue {
                    soundManager.playAutoplayOn()
                } else {
                    soundManager.playAutoplayOff()
                }
            }) {
                Image(systemName: autoplayEnabled.wrappedValue ? "steeringwheel.and.hands" : "steeringwheel")
                    .font(.system(size: 37))
                    .foregroundColor(autoplayEnabled.wrappedValue ? .white : .black)
                    .frame(width: 50, height: 50)  // Fixed width to accommodate widest icon
                    .frame(minWidth: 50, minHeight: 50)
                    .clipShape(Circle())
            }
            
            Button(action: {
                settingsOpen.wrappedValue.toggle()
                hapticsManager.toggleHaptic()
                if settingsOpen.wrappedValue {
                    isPaused.wrappedValue = true
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 37))
                    .foregroundColor(settingsOpen.wrappedValue ? .white : .black)
                    .frame(width: 50, height: 50)
                    .frame(minWidth: 50, minHeight: 50)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
        }
    }

struct ScoreHeader: View {
    let geometry: GeometryProxy
    let score: Int
    let highScore: Int
    
    var body: some View {
        HStack(spacing: geometry.size.width * 0.02) {
            AnimatedScoreView(
                score: highScore,
                isHighScore: true
            )
            .frame(maxHeight: .infinity)
            
            Spacer()
            
            Text("\(score)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.0))
        }
        .frame(height: geometry.size.height * 0.03)
        .padding(.horizontal, geometry.size.width * 0.02)
        .padding(.bottom, geometry.size.height * 0.007)
    }
}
    



struct DebugView: View {
    let width: CGFloat
    let height: CGFloat
    let layout: (squareSize: CGFloat, gameHeight: CGFloat, maxX: Int, maxY: Int)
    
    var body: some View {
        Color.clear
            .onAppear {
                print("🐍 DEBUG: Screen dimensions - width: \(width), height: \(height)")
                print("🐍 DEBUG: Layout dimensions - maxX: \(layout.maxX), maxY: \(layout.maxY)")
            }
    }
}
    
    #Preview {
        GameView()
    }

