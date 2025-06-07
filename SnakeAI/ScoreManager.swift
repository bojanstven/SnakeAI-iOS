import Foundation

struct GameStats: Codable {
    var totalGamesPlayed: Int
    var aiGamesPlayed: Int
    var totalPlaytime: TimeInterval
    var currentScore: Int
    var highScore: Int
}

@MainActor
class ScoreManager: ObservableObject {
    @Published var currentScore: Int = 0
    @Published var highScore: Int = 0
    @Published var isLoading = false
    @Published var stats: GameStats = GameStats(
        totalGamesPlayed: 0,
        aiGamesPlayed: 0,
        totalPlaytime: 0,
        currentScore: 0,
        highScore: 0
    )
    
    private var gameStartTime: Date?
    private let defaults = UserDefaults.standard
    private let highScoreKey = "SnakeHighScore"
    private let statsKey = "SnakeStats"
    
    init() {
        loadData()
    }
    
    private func loadData() {
        // Load high score
        highScore = defaults.integer(forKey: highScoreKey)
        
        // Load stats
        if let statsData = defaults.data(forKey: statsKey),
           let loadedStats = try? JSONDecoder().decode(GameStats.self, from: statsData) {
            stats = loadedStats
        }
    }
    
    func startNewGame(isAIEnabled: Bool) {
        gameStartTime = Date()
        stats.totalGamesPlayed += 1
        Achievements.shared.checkGamesPlayed(stats.totalGamesPlayed)
        if isAIEnabled {
            stats.aiGamesPlayed += 1
        }
        saveStats()
    }
    
    func endGame() {
        if let startTime = gameStartTime {
            stats.totalPlaytime += Date().timeIntervalSince(startTime)
            gameStartTime = nil
            saveStats()
        }
    }
    
    func updateScores(newScore: Int) {
        currentScore = newScore
        stats.currentScore = newScore
        if newScore > highScore {
            highScore = newScore
            stats.highScore = newScore
            saveHighScore()
            saveStats()
        }
    }
    
    private func saveHighScore() {
        defaults.set(highScore, forKey: highScoreKey)
    }
    
    private func saveStats() {
        if let encodedStats = try? JSONEncoder().encode(stats) {
            defaults.set(encodedStats, forKey: statsKey)
        }
    }
}

// Data deletion extension
extension ScoreManager {
    enum DeletionType {
        case highScoreOnly
        case allStats
    }
    
    func deleteData(_ type: DeletionType) {
        switch type {
        case .highScoreOnly:
            highScore = 0
            stats.highScore = 0
            defaults.removeObject(forKey: highScoreKey)
            saveStats()
            
        case .allStats:
            highScore = 0
            stats = GameStats(
                totalGamesPlayed: 0,
                aiGamesPlayed: 0,
                totalPlaytime: 0,
                currentScore: 0,
                highScore: 0
            )
            defaults.removeObject(forKey: highScoreKey)
            defaults.removeObject(forKey: statsKey)
        }
    }
}
