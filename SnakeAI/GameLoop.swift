import Foundation
import QuartzCore

class GameLoop: ObservableObject {
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var accumulatedTime: CFTimeInterval = 0
    private let maxAccumulatedTime: CFTimeInterval = 0.2  // Prevent spiral of death
    
    var frameCallback: (() -> Void)?
    var updateInterval: TimeInterval = 0.033  // About 30 updates per second
    
    init() {}
    
    func start() {
        lastUpdateTime = CACurrentMediaTime()
        accumulatedTime = 0  // Reset accumulated time on start
        displayLink = CADisplayLink(target: self, selector: #selector(frame))
        displayLink?.preferredFramesPerSecond = 60
        displayLink?.add(to: .main, forMode: .common)
        print("🐍 Game loop started with interval: \(updateInterval)")
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        accumulatedTime = 0
        print("🐍 Game loop stopped")
    }
    
    @objc private func frame() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        accumulatedTime += deltaTime
        
        // Handle multiple updates if needed
        while accumulatedTime >= updateInterval {
            frameCallback?()
            accumulatedTime -= updateInterval
            
            // Prevent excessive catch-up
            if accumulatedTime > maxAccumulatedTime {
                accumulatedTime = 0
                break
            }
        }
    }
}
