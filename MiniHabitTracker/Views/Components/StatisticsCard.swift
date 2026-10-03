import SwiftUI

struct StatisticsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let progress: Double?
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String, value: String, subtitle: String, icon: String, color: Color, progress: Double? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.progress = progress
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                if let progress = progress {
                    CircularProgressView(progress: progress, color: color)
                        .frame(width: 32, height: 32)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: 140) // Fixed height for consistency
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct StreakCard: View {
    let currentStreak: Int
    let longestStreak: Int
    let habitName: String
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(currentStreak)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Current Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Longest Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(longestStreak) days")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if currentStreak > 0 {
                    Text("🔥")
                        .font(.title2)
                }
            }
        }
        .frame(height: 140) // Fixed height for consistency
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    
    init(progress: Double, size: CGFloat = 60, lineWidth: CGFloat = 6, color: Color = .blue) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct AchievementCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isUnlocked ? color : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.circle.fill")
                .font(.title3)
                .foregroundColor(isUnlocked ? color : .secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
        )
    }
}
