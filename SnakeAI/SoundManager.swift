import AVFoundation
import Foundation

class SoundManager: ObservableObject {
    private var currentPlayer: AVAudioPlayer?
    private var sounds: [String: AVAudioPlayer] = [:]
    private let audioSession = AVAudioSession.sharedInstance()
    
    init() {
        configureAudioSession()
        loadSounds()
    }
    
    private func configureAudioSession() {
        do {
            // Use playback category with mix with others option
            try audioSession.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            
            // Set preferred sample rate and I/O buffer duration
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("🐍 Audio Session Config Error: \(error.localizedDescription)")
        }
    }
    
    private func loadSounds() {
        let soundNames = [
            "eat-food",
            "game-over",
            "game-pause",
            "game-unpause",
            "autoplay-on",
            "autoplay-off",
            "wall-switch-on",
            "wall-switch-off"
        ]
        
        for name in soundNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    // Configure player
                    player.prepareToPlay()
                    player.numberOfLoops = 0
                    player.volume = 1.0
                    player.enableRate = false  // Disable rate adjustment
                    
                    sounds[name] = player
                } catch {
                    print("🐍 Failed to load sound \(name): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func setVolume(_ volume: Float) {
        sounds.values.forEach { $0.volume = volume }
    }
    
    private func playSound(_ name: String) {
        guard let player = sounds[name] else { return }
        
        // Stop any currently playing sound
        stopAllSounds()
        
        // Ensure audio session is active before playing
        do {
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            }
        } catch {
            print("🐍 Failed to activate audio session: \(error.localizedDescription)")
            return
        }
        
        currentPlayer = player
        player.currentTime = 0
        player.play()
    }
    
    func stopAllSounds() {
        sounds.values.forEach { player in
            player.stop()
            player.currentTime = 0
        }
        currentPlayer = nil
    }
    
    func playEatFood() { playSound("eat-food") }
    func playGameOver() { playSound("game-over") }
    func playGamePause() { playSound("game-pause") }
    func playGameUnpause() { playSound("game-unpause") }
    func playAutoplayOn() { playSound("autoplay-on") }
    func playAutoplayOff() { playSound("autoplay-off") }
    func playWallSwitchOn() { playSound("wall-switch-on") }
    func playWallSwitchOff() { playSound("wall-switch-off") }
    
    deinit {
        stopAllSounds()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("🐍 Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}
