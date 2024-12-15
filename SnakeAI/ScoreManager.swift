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
    
    init() {
        // Empty init, no fetching here
    }
    
    func startNewGame(isAIEnabled: Bool) {
        gameStartTime = Date()
        stats.totalGamesPlayed += 1
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
    
    func fetchScores() async {
        isLoading = true
        print("🐍 Starting to fetch scores and stats from CloudKit...")
        
        let privateDB = container.privateCloudDatabase
        let highScoreSort = NSSortDescriptor(key: "highScore", ascending: false)
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [highScoreSort]
        
        do {
            let result = try await privateDB.records(matching: query, resultsLimit: 1)
            if let record = try? result.matchResults.first?.1.get() {
                self.recordID = record.recordID
                self.highScore = record["highScore"] as? Int ?? 0
                print("🐍 Successfully fetched high score: \(self.highScore)")
            } else {
                await self.saveHighScore()
                print("🐍 No records found, created initial record")
            }
            
            // Fetch stats
            let statsQuery = CKQuery(recordType: statsRecordType, predicate: NSPredicate(value: true))
            let statsResult = try await privateDB.records(matching: statsQuery, resultsLimit: 1)
            if let statsRecord = try? statsResult.matchResults.first?.1.get() {
                self.statsRecordID = statsRecord.recordID
                self.stats.totalGamesPlayed = statsRecord["totalGamesPlayed"] as? Int ?? 0
                self.stats.aiGamesPlayed = statsRecord["aiGamesPlayed"] as? Int ?? 0
                self.stats.totalPlaytime = statsRecord["totalPlaytime"] as? TimeInterval ?? 0
                print("🐍 Successfully fetched stats")
            } else {
                await self.saveStats()
                print("🐍 No stats found, created initial stats record")
            }
        } catch {
            print("🐍 Error fetching from CloudKit: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func updateScores(newScore: Int) {
        print("🐍 ScoreManager updating scores: current=\(currentScore), new=\(newScore), high=\(highScore)")
        currentScore = newScore
        stats.currentScore = newScore
        if newScore > highScore {
            print("🐍 New high score achieved!")
            highScore = newScore
            stats.highScore = newScore
            Task {
                await saveHighScore()
            }
        }
    }

    private func saveStats() {
        Task {
            let privateDB = container.privateCloudDatabase
            
            do {
                if let existingRecordID = statsRecordID {
                    if let record = try? await privateDB.record(for: existingRecordID) {
                        updateStatsRecord(record)
                        let savedRecord = try await privateDB.save(record)
                        self.statsRecordID = savedRecord.recordID
                        print("🐍 Successfully updated stats")
                        return
                    }
                }
                
                let newRecord = CKRecord(recordType: statsRecordType)
                updateStatsRecord(newRecord)
                let savedRecord = try await privateDB.save(newRecord)
                self.statsRecordID = savedRecord.recordID
                print("🐍 Successfully created new stats record")
            } catch {
                print("🐍 Error saving stats to CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateStatsRecord(_ record: CKRecord) {
        record["totalGamesPlayed"] = stats.totalGamesPlayed as CKRecordValue
        record["aiGamesPlayed"] = stats.aiGamesPlayed as CKRecordValue
        record["totalPlaytime"] = stats.totalPlaytime as CKRecordValue
    }
    
    private func saveHighScore() async {
        let privateDB = container.privateCloudDatabase
        
        do {
            if let existingRecordID = recordID {
                if let record = try? await privateDB.record(for: existingRecordID) {
                    record["highScore"] = highScore as CKRecordValue
                    let savedRecord = try await privateDB.save(record)
                    self.recordID = savedRecord.recordID
                    print("🐍 Successfully updated high score: \(highScore)")
                    return
                }
            }
            
            let newRecord = CKRecord(recordType: recordType)
            newRecord["highScore"] = highScore as CKRecordValue
            let savedRecord = try await privateDB.save(newRecord)
            self.recordID = savedRecord.recordID
            print("🐍 Successfully created new high score record: \(highScore)")
        } catch {
            print("🐍 Error saving to CloudKit: \(error.localizedDescription)")
        }
    }
}

extension ScoreManager {
    enum DeletionType {
        case highScoreOnly
        case allStats
    }
    
    func deleteData(_ type: DeletionType) async {
        let privateDB = container.privateCloudDatabase
        
        switch type {
        case .highScoreOnly:
            // Reset high score in memory
            highScore = 0
            stats.highScore = 0
            
            // Delete from CloudKit if exists
            if let recordID = recordID {
                do {
                    try await privateDB.deleteRecord(withID: recordID)
                    self.recordID = nil
                    print("🐍 Successfully deleted high score")
                } catch {
                    print("🐍 Error deleting high score: \(error.localizedDescription)")
                }
            }
            
        case .allStats:
            // Reset all stats in memory
            highScore = 0
            stats = GameStats(
                totalGamesPlayed: 0,
                aiGamesPlayed: 0,
                totalPlaytime: 0,
                currentScore: 0,
                highScore: 0
            )
            
            // Delete both records from CloudKit if they exist
            if let recordID = recordID {
                do {
                    try await privateDB.deleteRecord(withID: recordID)
                    self.recordID = nil
                    print("🐍 Successfully deleted high score record")
                } catch {
                    print("🐍 Error deleting high score: \(error.localizedDescription)")
                }
            }
            
            if let statsRecordID = statsRecordID {
                do {
                    try await privateDB.deleteRecord(withID: statsRecordID)
                    self.statsRecordID = nil
                    print("🐍 Successfully deleted stats record")
                } catch {
                    print("🐍 Error deleting stats: \(error.localizedDescription)")
                }
            }
        }
    }
}
