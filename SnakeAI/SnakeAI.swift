import Foundation

enum AILevel {
    case basic
    case smart
    case genius
}

protocol SnakeAIStrategy {
    func nextMove(snake: [Position],
                 food: Position,
                 boardSize: (width: Int, height: Int),
                  wallsOn: Bool) -> Direction
}

class SnakeAI: ObservableObject {
    @Published private(set) var currentLevel: AILevel
    @Published private(set) var lastDecision: Direction = .none
    
    private var strategy: SnakeAIStrategy
    
    init(level: AILevel = .basic) {
        self.currentLevel = level
        switch level {
        case .basic:
            self.strategy = BasicSnakeStrategy()
        case .smart:
            self.strategy = SmartSnakeStrategy()
        case .genius:
            self.strategy = GeniusSnakeStrategy()
        }
    }
    
    func calculateNextMove(snake: [Position],
                         food: Position,
                         boardSize: (width: Int, height: Int),
                           wallsOn: Bool) -> Direction {
        lastDecision = strategy.nextMove(snake: snake,
                                       food: food,
                                       boardSize: boardSize,
                                         wallsOn: wallsOn)
        return lastDecision
    }
    
    func changeLevel(to level: AILevel) {
        guard level != currentLevel else { return }
        currentLevel = level
        switch level {
        case .basic:
            self.strategy = BasicSnakeStrategy()
        case .smart:
            self.strategy = SmartSnakeStrategy()
        case .genius:
            self.strategy = GeniusSnakeStrategy()
        }
    }
}

class BasicSnakeStrategy: SnakeAIStrategy {
    func nextMove(snake: [Position], food: Position, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Direction {
        let head = snake[0]
        
        // Calculate distances considering wall wrapping if enabled
        let xDistance = getShortestDistance(from: head.x, to: food.x, boardSize: boardSize.width, wallsOn: wallsOn)
        let yDistance = getShortestDistance(from: head.y, to: food.y, boardSize: boardSize.height, wallsOn: wallsOn)
        
        // Determine if next move would cause self-collision
        func wouldCollide(_ nextPos: Position) -> Bool {
            return snake.contains(nextPos)
        }
        
        // Try horizontal movement first if it's the longer distance
        if abs(xDistance) >= abs(yDistance) {
            if xDistance > 0 {
                let nextPos = getNextPosition(head, direction: .right, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) {
                    return .right
                }
            } else if xDistance < 0 {
                let nextPos = getNextPosition(head, direction: .left, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) {
                    return .left
                }
            }
            
            // If horizontal movement would cause collision, try vertical
            if yDistance > 0 {
                let nextPos = getNextPosition(head, direction: .down, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) {
                    return .down
                }
            } else {
                let nextPos = getNextPosition(head, direction: .up, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) {
                    return .up
                }
            }
        }
        // Try vertical movement first if it's the longer distance
        else {
            if yDistance > 0 {
                let nextPos = getNextPosition(head, direction: .down, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) {
                    return .down
                }
            } else if yDistance < 0 {
                let nextPos = getNextPosition(head, direction: .up, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) {
                    return .up
                }
            }
            
            // If vertical movement would cause collision, try horizontal
            if xDistance > 0 {
                let nextPos = getNextPosition(head, direction: .right, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) {
                    return .right
                }
            } else {
                let nextPos = getNextPosition(head, direction: .left, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) {
                    return .left
                }
            }
        }
        
        // If all direct paths would cause collision, try any safe direction
        for direction in [Direction.up, .right, .down, .left] {
            let nextPos = getNextPosition(head, direction: direction, boardSize: boardSize, wallsOn: wallsOn)
            if !wouldCollide(nextPos) {
                return direction
            }
        }
        
        return .right // Last resort
    }
    
    private func getShortestDistance(from start: Int, to end: Int, boardSize: Int, wallsOn: Bool) -> Int {
        if wallsOn {
            return end - start
        }
        
        let direct = end - start
        let wrapAround = if direct > 0 {
            direct - boardSize
        } else {
            direct + boardSize
        }
        
        return abs(direct) < abs(wrapAround) ? direct : wrapAround
    }
    
    private func getNextPosition(_ current: Position, direction: Direction, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Position {
        var next = current
        
        switch direction {
        case .up:
            next.y -= 1
        case .down:
            next.y += 1
        case .left:
            next.x -= 1
        case .right:
            next.x += 1
        case .none:
            break
        }
        
        if !wallsOn {
            // Wrap around if needed
            if next.x < 0 { next.x = boardSize.width - 1 }
            if next.x >= boardSize.width { next.x = 0 }
            if next.y < 0 { next.y = boardSize.height - 1 }
            if next.y >= boardSize.height { next.y = 0 }
        }
        
        return next
    }
}

// Placeholder classes for now
class SmartSnakeStrategy: SnakeAIStrategy {
    func nextMove(snake: [Position], food: Position, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Direction {
        return .right
    }
}

class GeniusSnakeStrategy: SnakeAIStrategy {
    func nextMove(snake: [Position], food: Position, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Direction {
        return .right
    }
}
