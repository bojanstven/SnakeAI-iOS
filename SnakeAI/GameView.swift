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
    @State private var isPaused = false
    @StateObject private var scoreManager = ScoreManager()
    @State private var score = 0
    @State private var snakePositions = [Position(x: 0, y: 0)]
    @State private var foodPosition = Position(x: 0, y: 0)
    @State private var direction = Direction.right
    @State private var isGameOver = false
    @State private var gameTimer: Timer?
    @State private var lastDirection = Direction.right
    
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
        
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: moveInterval, repeats: true) { _ in
            moveSnake(maxX: layout.maxX, maxY: layout.maxY)
        }
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
        
        if newHead.x < 0 || newHead.x >= maxX || newHead.y < 0 || newHead.y >= maxY {
            endGame()
            return
        }
        
        if snakePositions.contains(newHead) {
            endGame()
            return
        }
        
        snakePositions.insert(newHead, at: 0)
        lastDirection = direction
        
        if newHead == foodPosition {
            scoreManager.updateScores(newScore: score + 1)
            score = score + 1
            generateNewFoodPosition(maxX: maxX, maxY: maxY)
            hapticsManager.foodEatenHaptic() // Add this line
        } else {
            snakePositions.removeLast()
        }
    }
    
    private func togglePause(maxX: Int, maxY: Int) {
        isPaused = !isPaused
        if isPaused {
            gameTimer?.invalidate()
            gameTimer = nil
        } else {
            gameTimer = Timer.scheduledTimer(withTimeInterval: moveInterval, repeats: true) { _ in
                moveSnake(maxX: maxX, maxY: maxY)
            }
        }
    }
    
    private func endGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        isGameOver = true
        hapticsManager.gameOverHaptic() // Add this line
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
                Color(red: 0.9, green: 1.0, blue: 0.9)
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

                    ZStack {
                        Rectangle()
                            .fill(Color(red: 0.9, green: 1.0, blue: 0.9))
                        
                        Rectangle()
                            .stroke(Color(red: 0.0, green: 0.5, blue: 0.0), lineWidth: frameWidth)
                        
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
                                        tryChangeDirection(horizontalAmount > 0 ? .right : .left)
                                    } else {
                                        tryChangeDirection(verticalAmount > 0 ? .down : .up)
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
                    
                    HStack(spacing: geometry.size.width * 0.05) {
                        Button(action: { tryChangeDirection(.left) }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { tryChangeDirection(.up) }) {
                            Image(systemName: "arrow.up")
                                .font(.title2)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { tryChangeDirection(.down) }) {
                            Image(systemName: "arrow.down")
                                .font(.title2)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { tryChangeDirection(.right) }) {
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color(red: 0.0, green: 0.5, blue: 0.0))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, geometry.size.height * 0.01)
                }
            }
            .onAppear {
                startGame(with: layout)
            }
        }
    }
}

#Preview {
    GameView()
}
