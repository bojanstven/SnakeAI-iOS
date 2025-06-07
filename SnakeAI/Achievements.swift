import Foundation
import GameKit

class Achievements: ObservableObject {
    static let shared = Achievements()

    // Achievement IDs (you'll set these up in App Store Connect)
    struct AchievementIDs {
        static let firstGamepad = "com.Bojanstven.SnakeAI.first_gamepad"        // Connect your first game controller
        static let play10Games = "com.Bojanstven.SnakeAI.play_10_games"         // Play 10 games
        static let score100Points = "com.Bojanstven.SnakeAI.score_100_points"   // Score 100 points in a single game
        static let beatAI = "com.Bojanstven.SnakeAI.beat_ai_snake"              // Beat the AI snake in race mode
        static let speedDemon = "com.Bojanstven.SnakeAI.speed_demon"            // Win a game with 2x speed active
    }
    
    private init() {
        authenticatePlayer()
    }
    
    private func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let error = error {
                print("🏆 GameKit auth error: \(error.localizedDescription)")
                return
            }
            
            if GKLocalPlayer.local.isAuthenticated {
                print("🏆 GameKit authenticated successfully!")
            }
        }
    }
    
    func unlockAchievement(_ achievementID: String) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        
        let achievement = GKAchievement(identifier: achievementID)
        achievement.percentComplete = 100.0
        achievement.showsCompletionBanner = true
        
        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("🏆 Achievement unlock error: \(error.localizedDescription)")
            } else {
                print("🏆 Achievement unlocked: \(achievementID)")
            }
        }
    }
    
    func updateProgressAchievement(_ achievementID: String, progress: Double) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        
        let achievement = GKAchievement(identifier: achievementID)
        achievement.percentComplete = min(100.0, progress)
        achievement.showsCompletionBanner = progress >= 100.0
        
        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("🏆 Achievement progress error: \(error.localizedDescription)")
            } else {
                print("🏆 Achievement progress: \(achievementID) - \(progress)%")
            }
        }
    }
    
    // Specific achievement triggers
    func checkFirstGamepad() {
        unlockAchievement(AchievementIDs.firstGamepad)
    }
    
    func checkGamesPlayed(_ count: Int) {
        let progress = Double(count) / 10.0 * 100.0
        updateProgressAchievement(AchievementIDs.play10Games, progress: progress)
    }
    
    func checkScore(_ score: Int) {
        if score >= 100 {
            unlockAchievement(AchievementIDs.score100Points)
        }
    }
    
    func checkBeatAI() {
        unlockAchievement(AchievementIDs.beatAI)
    }
    
    func checkSpeedDemon() {
        unlockAchievement(AchievementIDs.speedDemon)
    }
}
