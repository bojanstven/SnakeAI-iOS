import SwiftUI

enum PowerUpType: String, CaseIterable {
    case speed = "2× Speed"
    case slow = "½ Speed"
    case golden = "3× Points"
    
    var color: Color {
        switch self {
        case .speed: return Color(red: 0.5, green: 0.0, blue: 0.0)  // Dark red
        case .slow: return Color(red: 0.0, green: 0.3, blue: 0.0)   // Dark green
        case .golden: return Color(red: 1.0, green: 0.84, blue: 0.0) // Golden
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .golden: return 60.0
        default: return 10.0
        }
    }
    
    var speedMultiplier: Double {
        switch self {
        case .speed: return 2.0
        case .slow: return 0.5
        case .golden: return 1.0
        }
    }
    
    var scoreMultiplier: Int {
        switch self {
        case .golden: return 3
        default: return 1
        }
    }
}
struct PowerUpFood: Equatable {
    let position: Position
    let type: PowerUpType
    let createdAt: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) >= type.duration
    }
    
    var remainingTime: TimeInterval {
        max(0, type.duration - Date().timeIntervalSince(createdAt))
    }
    
    var progress: Double {
        remainingTime / type.duration
    }
}

struct ActivePowerUp: Equatable {
    let type: PowerUpType
    let expiresAt: Date
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
    
    var remainingTime: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    var progress: Double {
        remainingTime / type.duration
    }
}

struct PowerUpFoodView: View {
    let powerUp: PowerUpFood
    let size: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(powerUp.type.color)
            .frame(width: size - 1, height: size - 1)
    }
}

struct ActivePowerUpIndicator: View {
    let powerUp: ActivePowerUp
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(powerUp.type.color)
                .frame(width: 8, height: 8)
            
            Text(powerUp.type.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(powerUp.type.color)
            
            Text(String(format: "%.0fs", powerUp.remainingTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.1))
        )
    }
}

