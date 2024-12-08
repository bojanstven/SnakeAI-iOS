import SwiftUI

struct SplashScreen: View {
    @State private var isActive = false
    @State private var size = 0.5
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            GameView()
        } else {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    Text("SNAKE")
                        .font(.system(size: 50, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.size = 1.9  // Increased from 0.9 to 2.5 for bigger end size
                        self.opacity = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            self.isActive = true
                        }
                    }
                }
            }
        }
    }
}

struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen()
    }
}
