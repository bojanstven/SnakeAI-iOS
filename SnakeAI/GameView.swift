import SwiftUI
import GameController
import GameKit


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

enum BackgroundTheme: String, CaseIterable {
    case jungle = "Jungle Green"
    case ocean = "Ocean Blue"
    case desert = "Desert Brown"
    case dark = "Dark Mode"
    
    var colors: (light: Color, dark: Color) {
        switch self {
        case .jungle:
            return (Color(red: 0.55, green: 0.65, blue: 0.55),
                   Color(red: 0.51, green: 0.61, blue: 0.51))
        case .ocean:
            return (Color(red: 0.48, green: 0.56, blue: 0.65),
                   Color(red: 0.42, green: 0.50, blue: 0.59))
        case .desert:
            return (Color(red: 0.65, green: 0.55, blue: 0.48),
                   Color(red: 0.55, green: 0.44, blue: 0.30))
        case .dark:
            return (Color(red: 0.15, green: 0.15, blue: 0.15),
                   Color(red: 0.10, green: 0.10, blue: 0.10))
        }
    }
    
    var snakeColors: (head: Color, body: Color) {
        switch self {
        case .jungle:
            return (Color(red: 0.0, green: 0.3, blue: 0.0),
                   Color(red: 0.0, green: 0.5, blue: 0.0))
        case .ocean:
            return (Color(red: 0.0, green: 0.2, blue: 0.4),
                   Color(red: 0.1, green: 0.3, blue: 0.5))
        case .desert:
            return (Color(red: 0.4, green: 0.2, blue: 0.1),
                   Color(red: 0.5, green: 0.3, blue: 0.2))
        case .dark:
            return (Color(red: 0.3, green: 0.3, blue: 0.4),
                   Color(red: 0.4, green: 0.4, blue: 0.5))
        }
    }
}


extension UIDevice {
    var hasNotch: Bool {
        guard #available(iOS 13.0, *) else { return false }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top > 20
        }
        return false
    }
}


struct GameView: View {
    @StateObject private var hapticsManager = HapticsManager()
    @StateObject private var scoreManager = ScoreManager()
    @StateObject private var gameLoop = GameLoop()
    @StateObject private var snakeAI = SnakeAI(level: .smart)
    @StateObject private var soundManager = SoundManager()
    
    @StateObject private var achievementManager = Achievements.shared
    
    @State private var isPaused = false
    @State private var score = 0
    @State private var snakePositions = [Position(x: 0, y: 0)]
    @State private var foodPosition = Position(x: 0, y: 0)
    @State private var direction = Direction.right
    @State private var isGameOver = false
    @State private var lastDirection = Direction.right
    @State private var geometry: GeometryProxy?

    @State private var settingsOpen = false
    @State private var isInitialized = false

    @AppStorage("isSoundEnabled") private var isSoundEnabled = true
    @AppStorage("wallsOn") private var wallsOn = false
    @AppStorage("autoplayEnabled") private var autoplayEnabled = false
    @AppStorage("gameSpeed") private var gameSpeed: Int = 2

    @Environment(\.scenePhase) private var scenePhase
    
    private let moveInterval: TimeInterval = 0.2
    
    @State private var powerUpsEnabled = true
    @State private var enabledPowerUps: Set<PowerUpType> = Set(PowerUpType.allCases.filter { $0 != .slow })
    @State private var powerUpFoods: [PowerUpFood] = []
    @State private var activePowerUps: [ActivePowerUp] = []
    
    @AppStorage("selectedBackgroundTheme") private var selectedTheme: String = BackgroundTheme.jungle.rawValue
    @Environment(\.colorScheme) private var colorScheme

    
    
    private var activeTheme: BackgroundTheme {
        if colorScheme == .dark {
            return .dark
        } else {
            return BackgroundTheme(rawValue: selectedTheme) ?? .jungle
        }
    }
    
    private var scoreTextColor: Color {
        colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : .black
    }

    private var buttonIconColor: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.4, blue: 0.4) : .black
    }

    
    private var needsScoreRepositioning: Bool {
        UIDevice.current.userInterfaceIdiom == .phone &&
        getSafeAreaInsets().top > 44
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets
        }
        return .zero
    }

    
    private func calculateLayout(for geometry: GeometryProxy) -> (squareSize: CGFloat, gameHeight: CGFloat, maxX: Int, maxY: Int, offsetX: CGFloat, offsetY: CGFloat) {
        // Get the safe area insets
        let safeAreaInsets = getSafeAreaInsets()
        
        // Get total screen dimensions (ignoring safe area for edge-to-edge coverage)
        let totalWidth = geometry.size.width
        let totalHeight = geometry.size.height + safeAreaInsets.top + safeAreaInsets.bottom
        
        // Mathematical Perfect Division Approach
        let minTileSize: CGFloat = 15.0
        let maxTileSize: CGFloat = 25.0
        let squareTolerance: CGFloat = 0.5
        
        var bestSolution: (cols: Int, rows: Int, tileW: CGFloat, tileH: CGFloat, avgSize: CGFloat, difference: CGFloat)? = nil
        var maxAvgTileSize: CGFloat = 0
        
        // Test tile sizes in 0.1pt increments for precision
        var testSize = minTileSize
        while testSize <= maxTileSize {
            let cols = Int(round(totalWidth / testSize))
            let rows = Int(round(totalHeight / testSize))
            
            let actualTileW = totalWidth / CGFloat(cols)
            let actualTileH = totalHeight / CGFloat(rows)
            let tileDifference = abs(actualTileW - actualTileH)
            
            if tileDifference <= squareTolerance {
                let avgTileSize = (actualTileW + actualTileH) / 2
                
                if avgTileSize > maxAvgTileSize {
                    maxAvgTileSize = avgTileSize
                    bestSolution = (
                        cols: cols,
                        rows: rows,
                        tileW: actualTileW,
                        tileH: actualTileH,
                        avgSize: avgTileSize,
                        difference: tileDifference
                    )
                }
            }
            testSize += 0.1
        }
        
        guard let solution = bestSolution else {
            print("🐍 WARNING: No perfect square solution found, using fallback")
            let fallbackSize: CGFloat = 20.0
            let cols = Int(totalWidth / fallbackSize)
            let rows = Int(totalHeight / fallbackSize)
            return (
                squareSize: fallbackSize,
                gameHeight: totalHeight,
                maxX: cols,
                maxY: rows,
                offsetX: 0,
                offsetY: 0
            )
        }
        
        // Use the average size to maintain perfect squares
        let finalSquareSize = solution.avgSize
        
        // Calculate the total used space by the grid
        let usedWidth = CGFloat(solution.cols) * finalSquareSize
        let usedHeight = CGFloat(solution.rows) * finalSquareSize
        
        // Calculate remaining space and center the grid
        let remainingWidth = totalWidth - usedWidth
        let remainingHeight = totalHeight - usedHeight
        let offsetX = remainingWidth / 2
        let offsetY = remainingHeight / 2
    
        
        return (
            squareSize: finalSquareSize,
            gameHeight: totalHeight,
            maxX: solution.cols,
            maxY: solution.rows,
            offsetX: offsetX,
            offsetY: offsetY
        )
    }

    
    private func startGame(with layout: (squareSize: CGFloat, gameHeight: CGFloat, maxX: Int, maxY: Int, offsetX: CGFloat, offsetY: CGFloat)) {
        // Print debug info only when game starts
        print("🐍 DEBUG: Layout Calculations")
        print("Total Height: \(layout.gameHeight)")
        print("Square Size: \(layout.squareSize)")
        print("Grid: \(layout.maxX)x\(layout.maxY)")
        print("🐍 New game started! Grid size: \(layout.maxX)x\(layout.maxY)")

        gameLoop.stop()
        isGameOver = false
        isPaused = false
        
        // Clear all power-ups
        powerUpFoods.removeAll()
        activePowerUps.removeAll()

        
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
                
                // Count existing power-ups of this type
                let existingCount = powerUpFoods.filter { $0.type == randomPowerUp }.count
                
                // Only spawn if less than 2 of this type exist
                if existingCount < 2 {
                    var newPowerUpPosition: Position
                    repeat {
                        newPowerUpPosition = Position(
                            x: Int.random(in: 0..<maxX),
                            y: Int.random(in: topSafeRows..<maxY)
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
            achievementManager.checkScore(newScore)
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
        soundManager.setVolume(isSoundEnabled ? 1.0 : 0.0)
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
        soundManager.stopAllSounds()
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
    
    
    private func handleDirectionChange(_ newDirection: Direction, maxX: Int, maxY: Int, squareSize: CGFloat) {
        if !isPaused && !isGameOver && !autoplayEnabled {
            if newDirection == direction {
                // If trying to move in the same direction, force immediate move
                forceImmediateMove(maxX: maxX, maxY: maxY, squareSize: squareSize)
            } else if newDirection != direction.opposite && newDirection != lastDirection.opposite {
                // If it's a valid new direction, change direction
                direction = newDirection
            }
        } else {
            print("🐍 Game state prevented move - Paused: \(isPaused), GameOver: \(isGameOver), Autoplay: \(autoplayEnabled)")
        }
    }

    
    private func handleSwipe(gesture: DragGesture.Value, maxX: Int, maxY: Int, squareSize: CGFloat) {

        if !isPaused && !isGameOver && !autoplayEnabled {
            let horizontalAmount = gesture.translation.width
            let verticalAmount = gesture.translation.height
                        
            if abs(horizontalAmount) > abs(verticalAmount) {
                let newDirection = horizontalAmount > 0 ? Direction.right : Direction.left
                handleDirectionChange(newDirection, maxX: maxX, maxY: maxY, squareSize: squareSize)
            } else {
                let newDirection = verticalAmount > 0 ? Direction.down : Direction.up
                handleDirectionChange(newDirection, maxX: maxX, maxY: maxY, squareSize: squareSize)
            }
        } else {
            print("🐍 Game state prevented move - Paused: \(isPaused), GameOver: \(isGameOver), Autoplay: \(autoplayEnabled)")
        }
    }
    
    private func setupController(maxX: Int, maxY: Int, squareSize: CGFloat) {
        let controllers = GCController.controllers()
        let threshold: Float = 0.1
        
        for controller in controllers {

            if let gamepad = controller.extendedGamepad {
                // D-pad handling remains the same as it works well
                gamepad.dpad.valueChangedHandler = { [self] (_, xValue, yValue) in
                    if xValue == 1.0 && self.direction != .left && self.lastDirection != .left {
                        print("🎮 D-pad RIGHT")
                        self.handleDirectionChange(.right, maxX: maxX, maxY: maxY, squareSize: squareSize)
                    } else if xValue == -1.0 && self.direction != .right && self.lastDirection != .right {
                        print("🎮 D-pad LEFT")
                        self.handleDirectionChange(.left, maxX: maxX, maxY: maxY, squareSize: squareSize)
                    } else if yValue == 1.0 && self.direction != .down && self.lastDirection != .down {
                        print("🎮 D-pad UP")
                        self.handleDirectionChange(.up, maxX: maxX, maxY: maxY, squareSize: squareSize)
                    } else if yValue == -1.0 && self.direction != .up && self.lastDirection != .up {
                        print("🎮 D-pad DOWN")
                        self.handleDirectionChange(.down, maxX: maxX, maxY: maxY, squareSize: squareSize)
                    }
                }
                
                // Simplified stick handling
                var lastLeftStickDirection: Direction = .none
                var lastRightStickDirection: Direction = .none
                
                gamepad.leftThumbstick.valueChangedHandler = { [self] (_, xValue, yValue) in
                    let currentDirection = getStickDirection(x: xValue, y: yValue, threshold: threshold)
                    
                    if currentDirection != .none && currentDirection != lastLeftStickDirection {
                        print("🎮 Left stick direction: \(currentDirection)")
                        self.handleDirectionChange(currentDirection, maxX: maxX, maxY: maxY, squareSize: squareSize)
                        lastLeftStickDirection = currentDirection
                    } else if currentDirection == .none {
                        lastLeftStickDirection = .none
                    }
                }
                
                gamepad.rightThumbstick.valueChangedHandler = { [self] (_, xValue, yValue) in
                    let currentDirection = getStickDirection(x: xValue, y: yValue, threshold: threshold)
                    
                    if currentDirection != .none && currentDirection != lastRightStickDirection {
                        print("🎮 Right stick direction: \(currentDirection)")
                        self.handleDirectionChange(currentDirection, maxX: maxX, maxY: maxY, squareSize: squareSize)
                        lastRightStickDirection = currentDirection
                    } else if currentDirection == .none {
                        lastRightStickDirection = .none
                    }
                }
                
                // Game restart/pause - A and B buttons
                gamepad.buttonA.valueChangedHandler = { [self] (button, value, pressed) in
                    if pressed {
                        if isGameOver {
                            print("🎮 A button pressed - restarting game")
                            // Need to recalculate layout here
                            // This will need to be handled differently
                        } else {
                            print("🎮 A button pressed - toggling pause")
                            togglePause(maxX: maxX, maxY: maxY)
                        }
                    }
                }

                gamepad.buttonB.valueChangedHandler = { [self] (button, value, pressed) in
                    if pressed {
                        if isGameOver {
                            print("🎮 B button pressed - restarting game")
                            // Need to recalculate layout here
                            // This will need to be handled differently
                        } else {
                            print("🎮 B button pressed - toggling pause")
                            togglePause(maxX: maxX, maxY: maxY)
                        }
                    }
                }

                
                // Settings toggle - both + and - buttons
                gamepad.buttonOptions?.valueChangedHandler = { [self] (button, value, pressed) in
                    if pressed {
                        print("🎮 MINUS button pressed - toggling settings")
                        settingsOpen.toggle()
                        if settingsOpen {
                            isPaused = true
                        }
                    }
                }

                gamepad.buttonMenu.valueChangedHandler = { [self] (button, value, pressed) in
                    if pressed {
                        print("🎮 PLUS button pressed - toggling settings")
                        settingsOpen.toggle()
                        if settingsOpen {
                            isPaused = true
                        }
                    }
                }

                // Autoplay toggle - ZR, R and Z buttons
                gamepad.rightTrigger.valueChangedHandler = { [self] (button, value, pressed) in
                    if pressed {
                        print("🎮 ZR button pressed - toggling autoplay")
                        autoplayEnabled.toggle()
                        hapticsManager.toggleHaptic()
                        if autoplayEnabled {
                            soundManager.playAutoplayOn()
                        } else {
                            soundManager.playAutoplayOff()
                        }
                    }
                }

                gamepad.rightShoulder.valueChangedHandler = { [self] (button, value, pressed) in
                    if pressed {
                        print("🎮 R button pressed - toggling autoplay")
                        autoplayEnabled.toggle()
                        hapticsManager.toggleHaptic()
                        if autoplayEnabled {
                            soundManager.playAutoplayOn()
                        } else {
                            soundManager.playAutoplayOff()
                        }
                    }
                }

                
                // Sound toggle - ZL and L buttons
                gamepad.leftTrigger.valueChangedHandler = { [self] (button, value, pressed) in
                    if pressed {
                        print("🎮 ZL button pressed - toggling sound")
                        isSoundEnabled.toggle()
                        if isSoundEnabled {
                            soundManager.setVolume(1.0)
                        } else {
                            soundManager.setVolume(0.0)
                        }
                        hapticsManager.toggleHaptic()
                    }
                }

                gamepad.leftShoulder.valueChangedHandler = { [self] (button, value, pressed) in
                    if pressed {
                        print("🎮 L button pressed - toggling sound")
                        isSoundEnabled.toggle()
                        if isSoundEnabled {
                            soundManager.setVolume(1.0)
                        } else {
                            soundManager.setVolume(0.0)
                        }
                        hapticsManager.toggleHaptic()
                    }
                }
            }
            achievementManager.checkFirstGamepad()
        }
    }

    // helper function for stick direction
    private func getStickDirection(x: Float, y: Float, threshold: Float) -> Direction {
        if abs(x) < threshold && abs(y) < threshold {
            return .none
        }
        
        if abs(x) > abs(y) {
            return x > threshold ? .right : (x < -threshold ? .left : .none)
        } else {
            return y > threshold ? .up : (y < -threshold ? .down : .none)
        }
    }
    
    
    
    var body: some View {
        GeometryReader { geometry in
            let (squareSize, gameHeight, maxX, maxY, offsetX, offsetY) = calculateLayout(for: geometry)
            let buttonSize = min(geometry.size.width * 0.15, 50.0)
            
            ZStack {
                // Full screen background (matches dark tile color)
                activeTheme.colors.dark
                    .ignoresSafeArea()

                // Optimized game grid - only draw light tiles, skip dark ones
                GeometryReader { proxy in
                    ForEach(0..<maxY, id: \.self) { row in
                        ForEach(0..<maxX, id: \.self) { column in
                            if (row + column).isMultiple(of: 2) {
                                Rectangle()
                                    .fill(activeTheme.colors.light)
                                    .frame(width: squareSize, height: squareSize)
                                    .position(
                                        x: offsetX + squareSize * (CGFloat(column) + 0.5),
                                        y: offsetY + squareSize * (CGFloat(row) + 0.5)
                                    )
                            }
                            // Skip drawing dark tiles - background shows through naturally
                        }
                    }
                }
                .ignoresSafeArea()
                
                    
                // Snake (now rendered last/on top)
                GeometryReader { proxy in
                    ForEach(0..<snakePositions.count, id: \.self) { index in
                        Rectangle()
                            .fill(index == 0 ? activeTheme.snakeColors.head : activeTheme.snakeColors.body)
                            .frame(width: squareSize - 1, height: squareSize - 1)
                            .position(
                                x: offsetX + squareSize * (CGFloat(snakePositions[index].x) + 0.5),
                                y: offsetY + squareSize * (CGFloat(snakePositions[index].y) + 0.5)
                            )
                    }
                }
                .ignoresSafeArea()
                
                
                
                // Food and Power-ups
                GeometryReader { proxy in
                    // Regular food
                    Rectangle()
                        .fill(Color(red: 0.8, green: 0.0, blue: 0.0))
                        .frame(
                            width: squareSize - 1,
                            height: squareSize - 1
                        )
                        .position(
                            x: offsetX + squareSize * (CGFloat(foodPosition.x) + 0.5),
                            y: offsetY + squareSize * (CGFloat(foodPosition.y) + 0.5)
                        )
                    
                    // Power-up foods
                    ForEach(powerUpFoods, id: \.position) { powerUp in
                        PowerUpFoodView(powerUp: powerUp, size: squareSize)
                            .position(
                                x: offsetX + squareSize * (CGFloat(powerUp.position.x) + 0.5),
                                y: offsetY + squareSize * (CGFloat(powerUp.position.y) + 0.5)
                            )
                    }
                }
                .ignoresSafeArea()

                
                // Score header
                ScoreHeader(
                    geometry: geometry,
                    score: score,
                    highScore: scoreManager.highScore,
                    needsRepositioning: needsScoreRepositioning,
                    textColor: scoreTextColor
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, needsScoreRepositioning ? 0 : 0)
                
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
                        
                        Button(action: {
                            startGame(with: (squareSize: squareSize, gameHeight: gameHeight, maxX: maxX, maxY: maxY, offsetX: offsetX, offsetY: offsetY))
                        }) {
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
                        
                        Button(action: { togglePause(maxX: maxX, maxY: maxY) }) {
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
                    soundManager: soundManager,
                    gameLoop: gameLoop,
                    inactiveIconColor: buttonIconColor
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    if !isPaused && !isGameOver {
                        togglePause(maxX: maxX, maxY: maxY)
                    }
                }
            }
            
            .sheet(isPresented: $settingsOpen) {
                SettingsView(
                    isOpen: $settingsOpen,
                    wallsOn: $wallsOn,
                    autoplayEnabled: $autoplayEnabled,
                    isPaused: $isPaused,
                    snakeAI: snakeAI,
                    hapticsManager: hapticsManager,
                    gameLoop: gameLoop,
                    scoreManager: scoreManager,
                    isGameOver: $isGameOver,
                    gameSpeed: $gameSpeed,
                    powerUpsEnabled: $powerUpsEnabled,
                    enabledPowerUps: $enabledPowerUps,
                    isSoundEnabled: $isSoundEnabled,
                    selectedTheme: $selectedTheme,
                    baseIntervalForGameSpeed: baseIntervalForGameSpeed
                )
                .presentationDetents([.fraction(0.95)])
            }

            
            
            .onAppear {
                print("🐍 DEBUG: View appeared")
                selectedTheme = BackgroundTheme.jungle.rawValue
                print("🎮 Controllers found: \(GCController.controllers().count)")
                print("🏆 GameKit authenticated: \(GKLocalPlayer.local.isAuthenticated)")
                soundManager.setVolume(isSoundEnabled ? 1.0 : 0.0)
                let layout = calculateLayout(for: geometry)
                startGame(with: layout)
                setupController(maxX: layout.maxX, maxY: layout.maxY, squareSize: layout.squareSize)
                }
            
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { gesture in
                        handleSwipe(gesture: gesture, maxX: maxX, maxY: maxY, squareSize: squareSize)
                    }
            )
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        if !isGameOver && !settingsOpen {
                            togglePause(maxX: maxX, maxY: maxY)
                            
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
    let gameLoop: GameLoop
    let inactiveIconColor: Color
    
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
                    .foregroundColor(isSoundEnabled.wrappedValue ? .white : inactiveIconColor)
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
                    .foregroundColor(!wallsOn.wrappedValue ? .white : inactiveIconColor)
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
                    .foregroundColor(autoplayEnabled.wrappedValue ? .white : inactiveIconColor)
                    .frame(width: 50, height: 50)
                    .frame(minWidth: 50, minHeight: 50)
                    .clipShape(Circle())
            }
            
            Button(action: {
                settingsOpen.wrappedValue.toggle()
                hapticsManager.toggleHaptic()
                if settingsOpen.wrappedValue {
                    isPaused.wrappedValue = true
                    gameLoop.stop()
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 37))
                    .foregroundColor(settingsOpen.wrappedValue ? .white : inactiveIconColor)
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
    let needsRepositioning: Bool
    let textColor: Color
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        // Always center the scores, just adjust vertical position
        VStack(spacing: 3) {
            // High score on top
            Text("\(highScore)")
                .foregroundColor(textColor)
                .font(.title)
                .bold()
                .transition(.opacity.combined(with: .scale))
                .id(highScore)

            
            // Current score below
            Text("\(score)")
                .foregroundColor(textColor)
                .font(.title2)
                .bold()
                .transition(.opacity.combined(with: .scale))
                .id(score)

        }
        .offset(y: needsRepositioning ? 0 : (isIPad ? 20 : -10))
        .animation(.spring(response: 0.5, dampingFraction: 0.4), value: score)
        .animation(.spring(response: 0.5, dampingFraction: 0.4), value: highScore)
    }
}

    
    #Preview {
        GameView()
    }
