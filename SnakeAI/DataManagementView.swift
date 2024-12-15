import SwiftUI

struct DataManagementView: View {
    @ObservedObject var scoreManager: ScoreManager
    @State private var showingHighScoreAlert = false
    @State private var showingAllDataAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data Management")
                .font(.headline)
            
            VStack(spacing: 15) {
                // Reset High Score button
                Button(action: { showingHighScoreAlert = true }) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.red)
                            .frame(width: 30)
                        Text("Reset High Score")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .alert("Reset High Score?", isPresented: $showingHighScoreAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        isDeleting = true
                        Task {
                            await scoreManager.deleteData(.highScoreOnly)
                            isDeleting = false
                        }
                    }
                } message: {
                    Text("This will permanently delete your current high score of \(scoreManager.highScore). This action cannot be undone.")
                }
                
                // Reset All Data button
                Button(action: { showingAllDataAlert = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 30)
                        Text("Reset All Data")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .alert("Reset All Data?", isPresented: $showingAllDataAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset All", role: .destructive) {
                        isDeleting = true
                        Task {
                            await scoreManager.deleteData(.allStats)
                            isDeleting = false
                        }
                    }
                } message: {
                    Text("This will permanently delete all your game data including high score, total games played, and playtime statistics. This action cannot be undone.")
                }
            }
            .padding(.vertical, 5)
            .disabled(isDeleting)
            
            if isDeleting {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Deleting...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top)
            }
        }
    }
}
