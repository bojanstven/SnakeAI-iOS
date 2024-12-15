import SwiftUI

struct SettingsView: View {
    @Binding var isOpen: Bool
    @Binding var wallsOn: Bool
    @Binding var autoplayEnabled: Bool
    @Binding var isPaused: Bool
    @ObservedObject var snakeAI: SnakeAI
    @ObservedObject var hapticsManager: HapticsManager
    @ObservedObject var gameLoop: GameLoop
    @State private var speedLevel: Int = 1
    @State private var rotation: Double = -90
    @State private var previousPauseState: Bool
    @ObservedObject var scoreManager: ScoreManager
    
    @Binding var isGameOver: Bool
    @Binding var gameSpeed: Int

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2"
        return "Snake AI by Bojanstven - v\(version)"
    }
    
    private func iconForAILevel(_ level: AILevel) -> String {
        switch level {
        case .basic:
            return "lightbulb.fill"
        case .smart:
            return "lightbulb.min.fill"
        case .genius:
            return "lightbulb.max.fill"
        }
    }
    
    init(isOpen: Binding<Bool>,
         wallsOn: Binding<Bool>,
         autoplayEnabled: Binding<Bool>,
         snakeAI: SnakeAI,
         hapticsManager: HapticsManager,
         isPaused: Binding<Bool>,
         isGameOver: Binding<Bool>,
         gameLoop: GameLoop,
         gameSpeed: Binding<Int>,
         scoreManager: ScoreManager) {
        self._isOpen = isOpen
        self._wallsOn = wallsOn
        self._autoplayEnabled = autoplayEnabled
        self._isPaused = isPaused
        self._isGameOver = isGameOver
        self.snakeAI = snakeAI
        self.hapticsManager = hapticsManager
        self.gameLoop = gameLoop
        self._gameSpeed = gameSpeed
        self._previousPauseState = State(initialValue: isPaused.wrappedValue)
        self.scoreManager = scoreManager
    }

    private func closeSettings() {
        withAnimation(.spring(duration: 0.8)) {
            self.rotation = -90
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.isOpen = false
                if !isGameOver {
                    gameLoop.start()
                    isPaused = false
                }
            }
        }
    }
    
    private func updateGameSpeed(_ level: Int) {
        let intervals: [TimeInterval] = [0.3, 0.25, 0.2, 0.15, 0.1]
        gameLoop.updateInterval = intervals[level]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isOpen {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeSettings()
                        }
                    
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 20) {
                                headerView(geometry: geometry)
                                
                                // Game Settings
                                speedView()
                                Divider()
                                
                                // Controls Settings
                                wallsToggle()
                                autoplayToggle()
                                aiLevelView()
                                Divider()
                                
                                // Game Statistics
                                StatsView(scoreManager: scoreManager)
                                Divider()
                                
                                // Reset Options (renamed from Data Management)
                                DataManagementView(scoreManager: scoreManager)  // You might want to rename this struct too
                            }
                            .padding()
                        }
                        
                        versionView()
                    }
                    .frame(
                        width: min(geometry.size.width * 0.9, 500),
                        height: min(geometry.size.height * 0.8, 600)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(radius: 10)
                    )
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0.0, y: 1.0, z: 0.0)
                    )
                    .onAppear {
                        self.previousPauseState = isPaused
                        gameLoop.stop()
                        isPaused = true
                        withAnimation(.spring(duration: 0.8)) {
                            self.rotation = 0
                        }
                    }
                }
            }
        }
    }

    private func headerView(geometry: GeometryProxy) -> some View {
        HStack {
            Text("Settings")
                .font(.title)
                .bold()
            Spacer()
            Button(action: closeSettings) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func speedView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Speed")
                .font(.headline)
            
            HStack {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { Double(gameSpeed) },
                        set: { newValue in
                            let oldValue = gameSpeed
                            gameSpeed = Int(newValue)
                            if oldValue != gameSpeed {
                                hapticsManager.toggleHaptic()
                                updateGameSpeed(gameSpeed)
                                print("🐍 Speed changed to level: \(gameSpeed)")
                            }
                        }
                    ),
                    in: 0...4,
                    step: 1
                )
                .tint(Color(red: 0.0, green: 0.5, blue: 0.0))
                
                Image(systemName: "hare.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func wallsToggle() -> some View {
        Toggle(isOn: $wallsOn) {
            HStack {
                Image(systemName: wallsOn ? "shield.lefthalf.filled" : "shield.lefthalf.filled.slash")
                Text("Walls \(wallsOn ? "On" : "Off")")
                    .font(.headline)
            }
        }
        .tint(Color(red: 0.0, green: 0.5, blue: 0.0))
    }

    private func autoplayToggle() -> some View {
        Toggle(isOn: $autoplayEnabled) {
            HStack {
                Image(systemName: "brain.filled.head.profile")
                Text("AI Autoplay")
                    .font(.headline)
            }
        }
        .tint(Color(red: 0.0, green: 0.5, blue: 0.0))
    }

    private func aiLevelView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI Level")
                .font(.headline)
            
            HStack {
                ForEach([AILevel.basic, .smart, .genius], id: \.self) { level in
                    Button(action: {
                        if autoplayEnabled {
                            snakeAI.changeLevel(to: level)
                            hapticsManager.toggleHaptic()
                        }
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: iconForAILevel(level))
                                .font(.system(size: 24))
                                .frame(height: 30)
                            Text(String(describing: level).capitalized)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(snakeAI.currentLevel == level ?
                                     Color(red: 0.0, green: 0.5, blue: 0.0) :
                                     Color.secondary.opacity(0.2))
                        )
                        .foregroundColor(snakeAI.currentLevel == level ? .white : .primary)
                    }
                }
            }
            .disabled(!autoplayEnabled)
            .opacity(autoplayEnabled ? 1.0 : 0.5)
        }
    }

    private func versionView() -> some View {
        Text(appVersion)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 10)
    }
}
