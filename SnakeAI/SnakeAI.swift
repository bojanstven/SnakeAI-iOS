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
        print("🐍 AI Level changed to: \(level)")  // Add this debug print
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

// Helper methods used by all strategies
extension SnakeAIStrategy {
    func getNextPosition(_ current: Position, direction: Direction, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Position {
        var next = current
        
        switch direction {
        case .up: next.y -= 1
        case .down: next.y += 1
        case .left: next.x -= 1
        case .right: next.x += 1
        case .none: break
        }
        
        if !wallsOn {
            if next.x < 0 { next.x = boardSize.width - 1 }
            if next.x >= boardSize.width { next.x = 0 }
            if next.y < 0 { next.y = boardSize.height - 1 }
            if next.y >= boardSize.height { next.y = 0 }
        }
        
        return next
    }
    
    func getShortestDistance(from start: Int, to end: Int, boardSize: Int, wallsOn: Bool) -> Int {
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
    
    func manhattanDistance(_ from: Position, _ to: Position, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Int {
        let dx = abs(getShortestDistance(from: from.x, to: to.x, boardSize: boardSize.width, wallsOn: wallsOn))
        let dy = abs(getShortestDistance(from: from.y, to: to.y, boardSize: boardSize.height, wallsOn: wallsOn))
        return dx + dy
    }
}

class BasicSnakeStrategy: SnakeAIStrategy {
    func nextMove(snake: [Position], food: Position, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Direction {
        let head = snake[0]
        
        let xDistance = getShortestDistance(from: head.x, to: food.x, boardSize: boardSize.width, wallsOn: wallsOn)
        let yDistance = getShortestDistance(from: head.y, to: food.y, boardSize: boardSize.height, wallsOn: wallsOn)
        
        func wouldCollide(_ nextPos: Position) -> Bool {
            return snake.contains(nextPos)
        }
        
        if abs(xDistance) >= abs(yDistance) {
            if xDistance > 0 {
                let nextPos = getNextPosition(head, direction: .right, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) { return .right }
            } else if xDistance < 0 {
                let nextPos = getNextPosition(head, direction: .left, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) { return .left }
            }
            
            if yDistance > 0 {
                let nextPos = getNextPosition(head, direction: .down, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) { return .down }
            } else {
                let nextPos = getNextPosition(head, direction: .up, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) { return .up }
            }
        } else {
            if yDistance > 0 {
                let nextPos = getNextPosition(head, direction: .down, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) { return .down }
            } else if yDistance < 0 {
                let nextPos = getNextPosition(head, direction: .up, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) { return .up }
            }
            
            if xDistance > 0 {
                let nextPos = getNextPosition(head, direction: .right, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) { return .right }
            } else {
                let nextPos = getNextPosition(head, direction: .left, boardSize: boardSize, wallsOn: wallsOn)
                if !wouldCollide(nextPos) { return .left }
            }
        }
        
        for direction in [Direction.up, .right, .down, .left] {
            let nextPos = getNextPosition(head, direction: direction, boardSize: boardSize, wallsOn: wallsOn)
            if !wouldCollide(nextPos) { return direction }
        }
        
        return .right
    }
}

class SmartSnakeStrategy: SnakeAIStrategy {
    func nextMove(snake: [Position], food: Position, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Direction {
        let head = snake[0]
        var bestDirection = Direction.none
        var minDistance = Int.max
        
        // Look ahead for collisions
        func wouldCollideInSteps(_ pos: Position, steps: Int, visited: inout Set<Position>) -> Bool {
            if steps == 0 { return false }
            if snake.dropLast(steps).contains(pos) { return true }
            if visited.contains(pos) { return true }
            visited.insert(pos)
            return false
        }
        
        // Try each direction and evaluate safety
        for direction in [Direction.up, .right, .down, .left] {
            let nextPos = getNextPosition(head, direction: direction, boardSize: boardSize, wallsOn: wallsOn)
            var visited = Set<Position>()
            
            // Check if move is safe
            if !wouldCollideInSteps(nextPos, steps: 3, visited: &visited) {
                let distance = manhattanDistance(nextPos, food, boardSize: boardSize, wallsOn: wallsOn)
                
                // Prefer moves that keep distance from tail
                let tailDistance = manhattanDistance(nextPos, snake.last!, boardSize: boardSize, wallsOn: wallsOn)
                let adjustedDistance = distance - (tailDistance > 3 ? 2 : 0)
                
                if adjustedDistance < minDistance {
                    minDistance = adjustedDistance
                    bestDirection = direction
                }
            }
        }
        
        return bestDirection != .none ? bestDirection : .right
    }
}

class GeniusSnakeStrategy: SnakeAIStrategy {
    func nextMove(snake: [Position], food: Position, boardSize: (width: Int, height: Int), wallsOn: Bool) -> Direction {
        let head = snake[0]
        
        // First check if straight path is available and safe
        let xDistance = getShortestDistance(from: head.x, to: food.x, boardSize: boardSize.width, wallsOn: wallsOn)
        let yDistance = getShortestDistance(from: head.y, to: food.y, boardSize: boardSize.height, wallsOn: wallsOn)
        
        // Helper to check if a position would collide with walls or snake
        func isValidPosition(_ pos: Position) -> Bool {
            if wallsOn {
                if pos.x < 0 || pos.x >= boardSize.width || pos.y < 0 || pos.y >= boardSize.height {
                    return false
                }
            }
            return !snake.contains(pos)
        }
        
        // Try direct path first if it's clear
        if abs(xDistance) >= abs(yDistance) {
            if xDistance > 0 {
                let nextPos = getNextPosition(head, direction: .right, boardSize: boardSize, wallsOn: wallsOn)
                if isValidPosition(nextPos) { return .right }
            } else if xDistance < 0 {
                let nextPos = getNextPosition(head, direction: .left, boardSize: boardSize, wallsOn: wallsOn)
                if isValidPosition(nextPos) { return .left }
            }
        } else {
            if yDistance > 0 {
                let nextPos = getNextPosition(head, direction: .down, boardSize: boardSize, wallsOn: wallsOn)
                if isValidPosition(nextPos) { return .down }
            } else if yDistance < 0 {
                let nextPos = getNextPosition(head, direction: .up, boardSize: boardSize, wallsOn: wallsOn)
                if isValidPosition(nextPos) { return .up }
            }
        }
        
        // If direct path isn't available, use A* pathfinding
        func findPath() -> [Position] {
            var openSet = Set<Position>([head])
            var cameFrom = [Position: Position]()
            var gScore = [Position: Int]()
            var fScore = [Position: Int]()
            
            gScore[head] = 0
            fScore[head] = manhattanDistance(head, food, boardSize: boardSize, wallsOn: wallsOn)
            
            while !openSet.isEmpty {
                let current = openSet.min { fScore[$0, default: Int.max] < fScore[$1, default: Int.max] }!
                if current == food { return reconstructPath(cameFrom, current) }
                
                openSet.remove(current)
                
                for direction in [Direction.up, .right, .down, .left] {
                    let neighbor = getNextPosition(current, direction: direction, boardSize: boardSize, wallsOn: wallsOn)
                    if !isValidPosition(neighbor) { continue }
                    
                    let tentativeGScore = gScore[current, default: Int.max] + 1
                    if tentativeGScore < gScore[neighbor, default: Int.max] {
                        cameFrom[neighbor] = current
                        gScore[neighbor] = tentativeGScore
                        fScore[neighbor] = tentativeGScore + manhattanDistance(neighbor, food, boardSize: boardSize, wallsOn: wallsOn)
                        openSet.insert(neighbor)
                    }
                }
            }
            
            return []
        }
        
        func reconstructPath(_ cameFrom: [Position: Position], _ current: Position) -> [Position] {
            var path = [current]
            var current = current
            while let next = cameFrom[current] {
                path.append(next)
                current = next
            }
            return path.reversed()
        }
        
        // Find optimal path
        let path = findPath()
        if path.count >= 2 {
            let nextPos = path[1]
            if nextPos.x > head.x { return .right }
            if nextPos.x < head.x { return .left }
            if nextPos.y > head.y { return .down }
            if nextPos.y < head.y { return .up }
        }
        
        // Fallback to smart strategy if no path found
        return SmartSnakeStrategy().nextMove(snake: snake, food: food, boardSize: boardSize, wallsOn: wallsOn)
    }
}
