import SwiftUI

struct SparkleView: View {
    let sparkleCount = 12  // Increased number of particles
    
    // Golden color variations
    private let sparkleColors: [Color] = [
        Color(red: 1.0, green: 0.84, blue: 0.0),     // Pure gold
        Color(red: 1.0, green: 0.75, blue: 0.0),     // Darker gold
        Color(red: 1.0, green: 0.90, blue: 0.2),     // Lighter gold
        Color(red: 0.95, green: 0.85, blue: 0.4),    // Pale gold
        Color(red: 0.90, green: 0.77, blue: 0.0)     // Deep gold
    ]
    
    var body: some View {
        ZStack {
            ForEach(0..<sparkleCount, id: \.self) { index in
                SparkleParticle(
                    angle: Double(index) * (360.0 / Double(sparkleCount)),
                    color: sparkleColors[index % sparkleColors.count]
                )
            }
        }
    }
}

struct SparkleParticle: View {
    let angle: Double
    let color: Color
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 12))
            .foregroundColor(color)
            .offset(x: cos(angle * .pi / 180) * 30,
                   y: sin(angle * .pi / 180) * 30)
            .animation(.easeOut(duration: 1.0), value: angle)
    }
}

struct AnimatedScoreView: View {
    let score: Int
    let isHighScore: Bool
    
    @State private var scoreScale: CGFloat = 1.0
    @State private var crownScale: CGFloat = 1.0
    @State private var opacity: CGFloat = 1.0
    @State private var showSparkles = false
    
    private let goldColor = Color(red: 1.0, green: 0.84, blue: 0.0)
    
    private func animateNewHighScore() {
        // Reset states
        scoreScale = 1.0
        crownScale = 1.0
        opacity = 1.0
        showSparkles = false
        
        // Elegant scale animation for score and crown
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            scoreScale = 1.3
            crownScale = 1.4
        }
        
        // Show sparkles with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showSparkles = true
            
            withAnimation(.easeOut(duration: 2.0)) {
                opacity = 0
            }
            
            // Reset scale with slight delay and spring effect
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.3)) {
                scoreScale = 1.0
                crownScale = 1.0
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: geo.size.width * 0.02) {
                ZStack {
                    Image(systemName: "crown.fill")
                        .font(.title)
                        .foregroundColor(goldColor)
                        .scaleEffect(crownScale)
                        .offset(y: -geo.size.height * 0.35)
                    
                    if showSparkles {
                        SparkleView()
                            .opacity(opacity)
                            .offset(y: -geo.size.height * 0.35)
                    }
                }
                
                Text("\(score)")
                    .font(.title)
                    .bold()
                    .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.0))
                    .scaleEffect(scoreScale)
                    .offset(y: -geo.size.height * 0.25)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .onChange(of: score) { oldScore, newScore in
                if isHighScore && oldScore != newScore {
                    animateNewHighScore()
                }
            }
        }
    }
}
