import Foundation
import CloudKit

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
    
    private let container = CKContainer(identifier: "iCloud.com.Bojanstven.SnakeAI")
    private let recordType = "SnakeScore"
    private let statsRecordType = "SnakeStats"
    private var recordID: CKRecord.ID?
    private var statsRecordID: CKRecord.ID?
    private var gameStartTime: Date?
    
    // Remove timer-based approach as it causes actor isolation issues
    private var pendingStatsSave = false
    
    func startNewGame(isAIEnabled: Bool) {
        gameStartTime = Date()
        stats.totalGamesPlayed += 1
        if isAIEnabled {
            stats.aiGamesPlayed += 1
        }
        
        if !pendingStatsSave {
            pendingStatsSave = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                pendingStatsSave = false
                saveStats()
            }
        }
    }
    
    func endGame() {
        if let startTime = gameStartTime {
            stats.totalPlaytime += Date().timeIntervalSince(startTime)
            gameStartTime = nil
            saveStats()
        }
    }
    
    func fetchScores() async {
        isLoading = true
        
        let privateDB = container.privateCloudDatabase
        let highScoreSort = NSSortDescriptor(key: "highScore", ascending: false)
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [highScoreSort]
        
        do {
            let result = try await privateDB.records(matching: query, resultsLimit: 1)
            if let record = try? result.matchResults.first?.1.get() {
                self.recordID = record.recordID
                self.highScore = record["highScore"] as? Int ?? 0
            } else {
                Task { @MainActor in
                    self.saveHighScore()
                }
            }
            
            let statsQuery = CKQuery(recordType: statsRecordType, predicate: NSPredicate(value: true))
            let statsResult = try await privateDB.records(matching: statsQuery, resultsLimit: 1)
            if let statsRecord = try? statsResult.matchResults.first?.1.get() {
                self.statsRecordID = statsRecord.recordID
                self.stats.totalGamesPlayed = statsRecord["totalGamesPlayed"] as? Int ?? 0
                self.stats.aiGamesPlayed = statsRecord["aiGamesPlayed"] as? Int ?? 0
                self.stats.totalPlaytime = statsRecord["totalPlaytime"] as? TimeInterval ?? 0
            } else {
                saveStats()
            }
        } catch {
            print("🐍 Error fetching from CloudKit: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func updateScores(newScore: Int) {
        currentScore = newScore
        stats.currentScore = newScore
        if newScore > highScore {
            highScore = newScore
            stats.highScore = newScore
            Task { @MainActor in
                self.saveHighScore()
            }
        }
    }
    
    private func saveStats() {
        Task.detached(priority: .background) {
            let privateDB = self.container.privateCloudDatabase
            
            do {
                if let existingRecordID = await self.statsRecordID {
                    if let record = try? await privateDB.record(for: existingRecordID) {
                        await self.updateStatsRecord(record)
                        let savedRecord = try await privateDB.save(record)
                        await MainActor.run {
                            self.statsRecordID = savedRecord.recordID
                        }
                        return
                    }
                }
                
                let newRecord = CKRecord(recordType: self.statsRecordType)
                await self.updateStatsRecord(newRecord)
                let savedRecord = try await privateDB.save(newRecord)
                await MainActor.run {
                    self.statsRecordID = savedRecord.recordID
                }
            } catch {
                print("🐍 Error saving stats to CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateStatsRecord(_ record: CKRecord) {
        Task { @MainActor in
            record["totalGamesPlayed"] = stats.totalGamesPlayed as CKRecordValue
            record["aiGamesPlayed"] = stats.aiGamesPlayed as CKRecordValue
            record["totalPlaytime"] = stats.totalPlaytime as CKRecordValue
        }
    }
    
    private func saveHighScore() {
        Task.detached(priority: .background) {
            let privateDB = self.container.privateCloudDatabase
            
            do {
                if let existingRecordID = await self.recordID {
                    if let record = try? await privateDB.record(for: existingRecordID) {
                        record["highScore"] = await self.highScore as CKRecordValue
                        let savedRecord = try await privateDB.save(record)
                        await MainActor.run {
                            self.recordID = savedRecord.recordID
                        }
                        return
                    }
                }
                
                let newRecord = CKRecord(recordType: self.recordType)
                newRecord["highScore"] = await self.highScore as CKRecordValue
                let savedRecord = try await privateDB.save(newRecord)
                await MainActor.run {
                    self.recordID = savedRecord.recordID
                }
            } catch {
                print("🐍 Error saving to CloudKit: \(error.localizedDescription)")
            }
        }
    }
}

// Data deletion extension
extension ScoreManager {
    enum DeletionType {
        case highScoreOnly
        case allStats
    }
    
    func deleteData(_ type: DeletionType) async {
        let privateDB = container.privateCloudDatabase
        
        switch type {
        case .highScoreOnly:
            highScore = 0
            stats.highScore = 0
            
            if let recordID = recordID {
                do {
                    try await privateDB.deleteRecord(withID: recordID)
                    self.recordID = nil
                } catch {
                    print("🐍 Error deleting high score: \(error.localizedDescription)")
                }
            }
            
        case .allStats:
            highScore = 0
            stats = GameStats(
                totalGamesPlayed: 0,
                aiGamesPlayed: 0,
                totalPlaytime: 0,
                currentScore: 0,
                highScore: 0
            )
            
            if let recordID = recordID {
                do {
                    try await privateDB.deleteRecord(withID: recordID)
                    self.recordID = nil
                } catch {
                    print("🐍 Error deleting high score: \(error.localizedDescription)")
                }
            }
            
            if let statsRecordID = statsRecordID {
                do {
                    try await privateDB.deleteRecord(withID: statsRecordID)
                    self.statsRecordID = nil
                } catch {
                    print("🐍 Error deleting stats: \(error.localizedDescription)")
                }
            }
        }
    }
}
