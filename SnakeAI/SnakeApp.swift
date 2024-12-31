import SwiftUI
import GameController

@main
struct SnakeApp: App {
    init() {
        // Enable Game Mode and controller support
        GCController.shouldMonitorBackgroundEvents = true
        
        // Start wireless controller discovery
        Task {
            await GCController.startWirelessControllerDiscovery()
        }
        
        // Set up controller connection notifications
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { notification in
            print("🎮 Controller connected!")
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { notification in
            print("🎮 Controller disconnected!")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .statusBar(hidden: true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
