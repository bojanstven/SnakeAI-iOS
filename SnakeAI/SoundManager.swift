import AVFoundation
import Foundation

class SoundManager: ObservableObject {
    private var eatFoodSound: AVAudioPlayer?
    private var gameOverSound: AVAudioPlayer?
    private var gamePauseSound: AVAudioPlayer?
    private var gameUnpauseSound: AVAudioPlayer?
    private var autoplayOnSound: AVAudioPlayer?
    private var autoplayOffSound: AVAudioPlayer?
    private var wallSwitchOnSound: AVAudioPlayer?
    private var wallSwitchOffSound: AVAudioPlayer?
    private var gamepadConnectSound: AVAudioPlayer?
    
    init() {
        setupSounds()
    }
    
    private func setupSounds() {
        eatFoodSound = loadSound(fileName: "eat-food")
        gameOverSound = loadSound(fileName: "game-over")
        gamePauseSound = loadSound(fileName: "game-pause")
        gameUnpauseSound = loadSound(fileName: "game-unpause")
        autoplayOnSound = loadSound(fileName: "autoplay-on")
        autoplayOffSound = loadSound(fileName: "autoplay-off")
        wallSwitchOnSound = loadSound(fileName: "wall-switch-on")
        wallSwitchOffSound = loadSound(fileName: "wall-switch-off")
        gamepadConnectSound = loadSound(fileName: "gamepad-connect")
    }
    
    func setVolume(_ volume: Float) {
            eatFoodSound?.setVolume(volume, fadeDuration: 0)
            gameOverSound?.setVolume(volume, fadeDuration: 0)
            gamePauseSound?.setVolume(volume, fadeDuration: 0)
            gameUnpauseSound?.setVolume(volume, fadeDuration: 0)
            autoplayOnSound?.setVolume(volume, fadeDuration: 0)
            autoplayOffSound?.setVolume(volume, fadeDuration: 0)
            wallSwitchOnSound?.setVolume(volume, fadeDuration: 0)
            wallSwitchOffSound?.setVolume(volume, fadeDuration: 0)
            gamepadConnectSound?.setVolume(volume, fadeDuration: 0)
        }

    
    private func loadSound(fileName: String) -> AVAudioPlayer? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return player
            } catch {
                print("🐍 Error loading sound \(fileName): \(error.localizedDescription)")
            }
        }
        return nil
    }
    
    func playEatFood() {
        eatFoodSound?.play()
    }
    
    func playGameOver() {
        gameOverSound?.play()
    }
    
    func playGamePause() {
        gamePauseSound?.play()
    }
    
    func playGameUnpause() {
        gameUnpauseSound?.play()
    }
    
    func playAutoplayOn() {
        autoplayOnSound?.play()
    }
    
    func playAutoplayOff() {
        autoplayOffSound?.play()
    }
    
    func playWallSwitchOn() {
        wallSwitchOnSound?.play()
    }
    
    func playWallSwitchOff() {
        wallSwitchOffSound?.play()
    }
    
    func playGamepadConnect() {
        gamepadConnectSound?.play()
    }
}
