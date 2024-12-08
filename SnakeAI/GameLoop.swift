//
//  GameLoop.swift
//  SnakeAI
//
//  Created by Bojan Mijic on 09.12.2024.
//


import Foundation
import QuartzCore

class GameLoop: ObservableObject {
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var accumulatedTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 0.2  // Match your original moveInterval
    private let maxAccumulatedTime: CFTimeInterval = 0.4  // Prevent spiral of death
    
    var frameCallback: (() -> Void)?
    
    init() {}
    
    func start() {
        lastUpdateTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(frame))
        displayLink?.preferredFramesPerSecond = 60  // Keep this for smooth rendering
        displayLink?.add(to: .main, forMode: .common)
        print("Game loop started")
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        accumulatedTime = 0
        print("Game loop stopped")
    }
    
    @objc private func frame() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        accumulatedTime += deltaTime
        
        if accumulatedTime > maxAccumulatedTime {
            accumulatedTime = maxAccumulatedTime
        }
        
        if accumulatedTime >= updateInterval {  // Only update when enough time has passed
            frameCallback?()
            accumulatedTime = 0  // Reset accumulated time after update
        }
    }
}
