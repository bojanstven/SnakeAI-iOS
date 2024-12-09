import Foundation
import CloudKit

struct Score: Codable {
    var currentScore: Int
    var highScore: Int
}

@MainActor
class ScoreManager: ObservableObject {
    @Published var currentScore: Int = 0
    @Published var highScore: Int = 0
    @Published var isLoading = false
    
    private let container = CKContainer(identifier: "iCloud.com.Bojanstven.SnakeAI")
    private let recordType = "SnakeScore"
    private var recordID: CKRecord.ID?
    
    init() {
        // Empty init, no fetching here
    }
    
    func fetchScores() async {
        isLoading = true
        print("🐍 Starting to fetch scores from CloudKit...")
        
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
                // No records found, create initial record
                await self.saveHighScore()
                print("🐍 No records found, created initial record")
            }
        } catch {
            print("🐍 Error fetching from CloudKit: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func updateScores(newScore: Int) {
        currentScore = newScore
        if newScore > highScore {
            highScore = newScore
            Task {
                await saveHighScore()
            }
        }
    }
    
    private func saveHighScore() async {
        let privateDB = container.privateCloudDatabase
        
        do {
            if let existingRecordID = recordID {
                // Try to fetch existing record
                if let record = try? await privateDB.record(for: existingRecordID) {
                    record["highScore"] = highScore as CKRecordValue
                    let savedRecord = try await privateDB.save(record)
                    self.recordID = savedRecord.recordID
                    print("🐍 Successfully updated high score: \(highScore)")
                    return
                }
            }
            
            // Create new record if no existing record or fetch failed
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
