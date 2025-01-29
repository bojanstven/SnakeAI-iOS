import SwiftUI


struct AnimatedScoreView: View {
    let score: Int
    let isHighScore: Bool
    
    @State private var scoreScale: CGFloat = 1.0
    @State private var crownScale: CGFloat = 1.0
    
    private let goldColor = Color(red: 1.0, green: 0.84, blue: 0.0)
    
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: geo.size.width * 0.02) {
                Image(systemName: "crown.fill")
                    .font(.title)
                    .foregroundColor(goldColor)
                    .scaleEffect(crownScale)
                    .offset(y: -geo.size.height * 0.35)
                
                Text("\(score)")
                    .font(.title)
                    .bold()
                    .foregroundColor(.black)  // Changed from green to black
                    .scaleEffect(scoreScale)
                    .offset(y: -geo.size.height * 0.25)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .onChange(of: score) { oldScore, newScore in
                if isHighScore && newScore > oldScore {
                    print("🐍 Animating high score increase: \(oldScore) -> \(newScore)")
                    
                    // Reset scales first
                    scoreScale = 1.0
                    crownScale = 1.0
                    
                    // Perform the scale up animation
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        scoreScale = 1.3
                        crownScale = 1.4
                    }
                    
                    // Reset after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            scoreScale = 1.0
                            crownScale = 1.0
                        }
                    }
                }
            }
        }
    }
}
