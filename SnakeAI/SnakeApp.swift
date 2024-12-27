import SwiftUI

@main
struct SnakeApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .statusBar(hidden: true)
                .persistentSystemOverlays(.hidden)  // Hides Dynamic Island on iPhone 14 Pro and newer

        }
    }
}
