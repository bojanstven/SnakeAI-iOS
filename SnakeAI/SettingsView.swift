import SwiftUI

struct SettingsView: View {
    @Binding var isOpen: Bool
    @Binding var wallsOn: Bool
    @Binding var autoplayEnabled: Bool
    @Binding var isPaused: Bool
    @ObservedObject var snakeAI: SnakeAI
    @ObservedObject var hapticsManager: HapticsManager
    @ObservedObject var gameLoop: GameLoop
    @ObservedObject var scoreManager: ScoreManager
    @Binding var isGameOver: Bool
    @Binding var gameSpeed: Int
    @Binding var powerUpsEnabled: Bool
    @Binding var enabledPowerUps: Set<PowerUpType>
    @Binding var isSoundEnabled: Bool
    @Binding var selectedTheme: String
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingHighScoreAlert = false
    @State private var showingAllDataAlert = false
    
    let baseIntervalForGameSpeed: (Int) -> TimeInterval
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2"
        return "Snake AI by Bojanstven - v\(version)"
    }
    
    init(isOpen: Binding<Bool>,
         wallsOn: Binding<Bool>,
         autoplayEnabled: Binding<Bool>,
         isPaused: Binding<Bool>,
         snakeAI: SnakeAI,
         hapticsManager: HapticsManager,
         gameLoop: GameLoop,
         scoreManager: ScoreManager,
         isGameOver: Binding<Bool>,
         gameSpeed: Binding<Int>,
         powerUpsEnabled: Binding<Bool>,
         enabledPowerUps: Binding<Set<PowerUpType>>,
         isSoundEnabled: Binding<Bool>,
         selectedTheme: Binding<String>,
         baseIntervalForGameSpeed: @escaping (Int) -> TimeInterval) {
        self._isOpen = isOpen
        self._wallsOn = wallsOn
        self._autoplayEnabled = autoplayEnabled
        self._isPaused = isPaused
        self.snakeAI = snakeAI
        self.hapticsManager = hapticsManager
        self.gameLoop = gameLoop
        self.scoreManager = scoreManager
        self._isGameOver = isGameOver
        self._gameSpeed = gameSpeed
        self._powerUpsEnabled = powerUpsEnabled
        self._enabledPowerUps = enabledPowerUps
        self._isSoundEnabled = isSoundEnabled
        self.baseIntervalForGameSpeed = baseIntervalForGameSpeed
        self._selectedTheme = selectedTheme
    }
    
    
    
    var body: some View {
        NavigationView {
            List {
                // Game Controls Section
                Section {
                    speedControl
                    
                    Toggle(isOn: $isSoundEnabled) {
                        HStack {
                            Image(systemName: isSoundEnabled ? "bell.fill" : "bell.slash.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 30)
                            Text("Sound Effects")
                        }
                    }
                    .tint(Color(red: 0.0, green: 0.5, blue: 0.0))
                    
                    Toggle(isOn: $wallsOn) {
                        HStack {
                            Image(systemName: wallsOn ? "shield.slash.fill" : "firewall.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 30)
                            Text("Walls")
                        }
                    }
                    .tint(Color(red: 0.0, green: 0.5, blue: 0.0))
                } header: {
                    Text("Game Controls")
                }
                
                // AI Settings Section
                Section {
                    Toggle(isOn: $autoplayEnabled) {
                        HStack {
                            Image(systemName: autoplayEnabled ? "steeringwheel.and.hands" : "steeringwheel")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 30)
                            Text("AI Autopilot")
                        }
                    }
                    .tint(Color(red: 0.0, green: 0.5, blue: 0.0))
                    
                    // AI Level selection - always visible, greyed out when disabled
                    HStack(alignment: .top, spacing: 12) {
                        // Simple gauge icon that switches immediately (no animation)
                        Image(systemName: getAILevelIcon(snakeAI.currentLevel))
                            .font(.system(size: 22))
                            .foregroundColor(autoplayEnabled ? .primary : .secondary)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // Title at same level as gauge icon
                            Text("AI Intelligence Level")
                                .font(.body)
                                .foregroundColor(autoplayEnabled ? .primary : .secondary)
                            
                            // Segmented control - always visible but disabled when AI off
                            Picker("AI Level", selection: Binding(
                                get: { snakeAI.currentLevel },
                                    set: {
                                        hapticsManager.toggleHaptic()  // Add this line
                                        snakeAI.changeLevel(to: $0)
                                    }
                            )) {
                                Text("Basic").tag(AILevel.basic)
                                Text("Smart").tag(AILevel.smart)
                                Text("Genius").tag(AILevel.genius)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(height: 44)
                            .disabled(!autoplayEnabled)
                            .opacity(autoplayEnabled ? 1.0 : 0.6)
                        }
                    }
                } header: {
                    Text("AI Settings")
                } footer: {
                    if autoplayEnabled {
                        Text("Basic: Simple pathfinding • Smart: Collision avoidance • Genius: Advanced AI algorithm")
                    } else {
                        Text("Enable AI autopilot to choose intelligence level")
                    }
                }
                
                
                // Background Theme Section
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Background Theme")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                ForEach([BackgroundTheme.jungle, .ocean, .desert], id: \.self) { theme in
                                    Button(action: {
                                        if colorScheme == .light {
                                            selectedTheme = theme.rawValue
                                            hapticsManager.toggleHaptic()
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            VStack(spacing: 1) {
                                                HStack(spacing: 1) {
                                                    Rectangle()
                                                        .fill(theme.colors.light)
                                                        .frame(width: 12, height: 12)
                                                    Rectangle()
                                                        .fill(theme.colors.dark)
                                                        .frame(width: 12, height: 12)
                                                }
                                                HStack(spacing: 1) {
                                                    Rectangle()
                                                        .fill(theme.colors.dark)
                                                        .frame(width: 12, height: 12)
                                                    Rectangle()
                                                        .fill(theme.colors.light)
                                                        .frame(width: 12, height: 12)
                                                }
                                            }
                                            .cornerRadius(3)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .stroke(selectedTheme == theme.rawValue && colorScheme == .light ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                            
                                            Text(theme.rawValue)
                                                .font(.caption2)
                                                .foregroundColor(colorScheme == .dark ? .secondary : .primary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(colorScheme == .dark)
                                    .opacity(colorScheme == .dark ? 0.6 : 1.0)
                                }
                                
                                Button(action: {}) {
                                    VStack(spacing: 4) {
                                        VStack(spacing: 1) {
                                            HStack(spacing: 1) {
                                                Rectangle()
                                                    .fill(BackgroundTheme.dark.colors.light)
                                                    .frame(width: 12, height: 12)
                                                Rectangle()
                                                    .fill(BackgroundTheme.dark.colors.dark)
                                                    .frame(width: 12, height: 12)
                                            }
                                            HStack(spacing: 1) {
                                                Rectangle()
                                                    .fill(BackgroundTheme.dark.colors.dark)
                                                    .frame(width: 12, height: 12)
                                                Rectangle()
                                                    .fill(BackgroundTheme.dark.colors.light)
                                                    .frame(width: 12, height: 12)
                                            }
                                        }
                                        .cornerRadius(3)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(colorScheme == .dark ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                        
                                        Text("Dark Mode")
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(true)
                            }
                        }
                    }
                } header: {
                    Text("Background")
                } footer: {
                    if colorScheme == .dark {
                        Text("Dark Mode is automatically active. Switch to Light Mode to choose other themes.")
                    } else {
                        Text("Choose your preferred background theme. Dark Mode activates automatically when system dark mode is enabled.")
                    }
                }
                
                
                
                // Power-ups Section
                Section {
                    Toggle(isOn: $powerUpsEnabled) {
                        HStack {
                            Image(systemName: powerUpsEnabled ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 30)
                            Text("Power-ups")
                        }
                    }
                    .tint(Color(red: 0.0, green: 0.5, blue: 0.0))
                } header: {
                    Text("Power-ups")
                } footer: {
                    Text("Collect power-ups: 3× points, 2× speed, ½ speed")
                }

                
                // Statistics Section
                Section {
                    statsRows
                } header: {
                    Text("Statistics")
                }
                
                // Data Management Section
                Section {
                    dataManagementRows
                } header: {
                    Text("Data Management")
                } footer: {
                    Text(appVersion)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isOpen = false
                        if !isGameOver {
                            gameLoop.start()
                            isPaused = false
                        }
                    }
                }
            }
        }
    }
    
    private var speedControl: some View {
        HStack {
            Image(systemName: "tortoise.fill")
                .foregroundColor(.secondary)
            Slider(
                value: Binding(
                    get: { Double(gameSpeed) },
                    set: { newValue in
                        let oldValue = gameSpeed
                        gameSpeed = Int(newValue)
                        if oldValue != gameSpeed {
                            hapticsManager.toggleHaptic()
                            gameLoop.updateInterval = baseIntervalForGameSpeed(gameSpeed)
                        }
                    }
                ),
                in: 0...4,
                step: 1
            )
            .tint(Color(red: 0.0, green: 0.5, blue: 0.0))
            Image(systemName: "hare.fill")
                .foregroundColor(.secondary)
        }
    }
    
    private func getAILevelIcon(_ level: AILevel) -> String {
        switch level {
        case .basic: return "gauge.low"
        case .smart: return "gauge.medium"
        case .genius: return "gauge.high"
        }
    }
    
    private var statsRows: some View {
        Group {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
                    .frame(width: 30)
                Text("High Score")
                Spacer()
                Text("\(scoreManager.highScore)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
                    .frame(width: 30)
                Text("Games Played")
                Spacer()
                Text("\(scoreManager.stats.totalGamesPlayed)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "brain.filled.head.profile")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
                    .frame(width: 30)
                Text("AI Games")
                Spacer()
                Text("\(scoreManager.stats.aiGamesPlayed)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
                    .frame(width: 30)
                Text("Total Playtime")
                Spacer()
                Text(formatTime(scoreManager.stats.totalPlaytime))
                    .foregroundColor(.secondary)
            }
        }
    }
    

        private var dataManagementRows: some View {
            Group {
                Button(role: .destructive) {
                    showingHighScoreAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 22))
                            .frame(width: 30)
                        Text("Reset High Score")
                    }
                }
                .alert("Reset High Score?", isPresented: $showingHighScoreAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        scoreManager.deleteData(.highScoreOnly)
                    }
                } message: {
                    Text("This will permanently delete your current high score of \(scoreManager.highScore). This action cannot be undone.")
                }
                
                Button(role: .destructive) {
                    showingAllDataAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 22))
                            .frame(width: 30)
                        Text("Reset All Data")
                    }
                }
                .alert("Reset All Data?", isPresented: $showingAllDataAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset All", role: .destructive) {
                        scoreManager.deleteData(.allStats)
                    }
                } message: {
                    Text("This will permanently delete all your game data including high score, total games played, and playtime statistics. This action cannot be undone.")
                }
            }
        }
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
}



struct ThemePreviewButton: View {
    let theme: BackgroundTheme
    let isSelected: Bool
    let isDisabled: Bool
    @Binding var selectedTheme: String
    let colorScheme: ColorScheme
    let hapticsManager: HapticsManager
        
    var body: some View {
        Button(action: {
            print("🎨 BUTTON: Tapped \(theme.rawValue), colorScheme=\(colorScheme), current selectedTheme='\(selectedTheme)'")
            if colorScheme == .light && theme != .dark {
                print("🎨 BUTTON: Setting selectedTheme to '\(theme.rawValue)'")
                selectedTheme = theme.rawValue
                hapticsManager.toggleHaptic()
            } else {
                print("🎨 BUTTON: Action blocked - colorScheme=\(colorScheme), theme=\(theme)")
            }
        }) {
            VStack(spacing: 4) {
                // 2x2 preview grid
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        Rectangle()
                            .fill(theme.colors.light)
                            .frame(width: 12, height: 12)
                        Rectangle()
                            .fill(theme.colors.dark)
                            .frame(width: 12, height: 12)
                    }
                    HStack(spacing: 1) {
                        Rectangle()
                            .fill(theme.colors.dark)
                            .frame(width: 12, height: 12)
                        Rectangle()
                            .fill(theme.colors.light)
                            .frame(width: 12, height: 12)
                    }
                }
                .cornerRadius(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                
                Text(theme.rawValue)
                    .font(.caption2)
                    .foregroundColor(isDisabled ? .secondary : .primary)
            }
        }
        .disabled(isDisabled && theme != .dark)
        .opacity(isDisabled && theme != .dark ? 0.6 : 1.0)
    }
}
