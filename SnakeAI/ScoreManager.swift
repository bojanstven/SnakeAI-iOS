import Foundation
import CloudKit

struct Score: Codable {
    var currentScore: Int
    var highScore: Int
}

class ScoreManager: ObservableObject {
    @Published var currentScore: Int = 0
    @Published var highScore: Int = 0
    
    private let container = CKContainer.default()
    private let recordType = "SnakeScore"
    
    init() {
        fetchScores()
    }
    
    func fetchScores() {
        let privateDB = container.privateCloudDatabase
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
            switch result {
            case .success((let matchResults, _)):
                DispatchQueue.main.async {
                    if let firstMatch = matchResults.first {
                        switch firstMatch.1 {
                        case .success(let record):
                            self?.highScore = record["highScore"] as? Int ?? 0
                        case .failure(let error):
                            print("Error accessing record: \(error.localizedDescription)")
                        }
                    }
                }
            case .failure(let error):
                print("Error fetching from CloudKit: \(error.localizedDescription)")
            }
        }
    }

    func updateScores(newScore: Int) {
        currentScore = newScore
        if newScore > highScore {
            highScore = newScore
            saveHighScore()
        }
    }
    
    private func saveHighScore() {
        let privateDB = container.privateCloudDatabase
        let record = CKRecord(recordType: recordType)
        record["highScore"] = highScore as CKRecordValue
        
        privateDB.save(record) { record, error in
            if let error = error {
                print("Error saving to CloudKit: \(error.localizedDescription)")
                return
            }
        }
    }
}
