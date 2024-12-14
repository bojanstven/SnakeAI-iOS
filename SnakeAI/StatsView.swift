import SwiftUI

struct StatsView: View {
    @ObservedObject var scoreManager: ScoreManager
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Statistics")
                .font(.headline)
            
            VStack(spacing: 15) {
                StatRow(
                    icon: "trophy.fill",
                    label: "High Score",
                    value: "\(scoreManager.highScore)"
                )
                
                StatRow(
                    icon: "gamecontroller.fill",
                    label: "Games Played",
                    value: "\(scoreManager.stats.totalGamesPlayed)"
                )
                
                StatRow(
                    icon: "brain.filled.head.profile",
                    label: "AI Games",
                    value: "\(scoreManager.stats.aiGamesPlayed)"
                )
                
                StatRow(
                    icon: "clock.fill",
                    label: "Total Playtime",
                    value: formatTime(scoreManager.stats.totalPlaytime)
                )
                
                if scoreManager.stats.totalGamesPlayed > 0 {
                    StatRow(
                        icon: "percent",
                        label: "AI Games Ratio",
                        value: String(format: "%.1f%%",
                            Double(scoreManager.stats.aiGamesPlayed) /
                            Double(scoreManager.stats.totalGamesPlayed) * 100
                        )
                    )
                }
            }
            .padding(.vertical, 5)
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            Text(label)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
                .bold()
        }
    }
}
