import SwiftUI

struct HabitCard: View {
	let habit: Habit
	let isCompleted: Bool
	let onToggle: () -> Void
	let onTap: () -> Void
	
	@Environment(HabitStore.self) private var habitStore
	@Environment(\.colorScheme) private var colorScheme
	@State private var trigger: Int = 0
	@State private var waveOrigin: CGPoint = CGPoint(x: 4, y: 3)
	
	var body: some View {
        let todayTotal = habitStore.getTotalCompletions(for: habit.id, on: Date())
        let miniCalendarIntensities = recentMiniCalendarIntensities()
		Button(action: onTap) {
			HStack(spacing: 14) {
				// Icon and Color
				ZStack {
					Circle()
						.fill(habit.displayColor.opacity(0.2))
						.frame(width: 48, height: 48)
					
					Image(systemName: "star.fill")
						.font(.title2)
						.foregroundColor(habit.displayColor)
				}
				
				// Habit Details
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text(habit.name)
							.font(.body)
							.foregroundColor(.primary)
							.lineLimit(2)
						
						Spacer()
						
						if habit.streak > 0 {
							HStack(spacing: 4) {
								Image(systemName: "flame.fill")
									.font(.caption)
									.foregroundColor(.orange)
								
								Text("\(habit.streak)")
									.font(.caption)
									.fontWeight(.semibold)
									.foregroundColor(.secondary)
							}
						}
					}
					
					HStack(spacing: 8) {
						Text(progressText(todayTotal: todayTotal))
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				
				// Mini Calendar with Wave Animation
				VStack(spacing: 4) {
					// Week overview (7 days)
					HStack(spacing: 2) {
						ForEach(0..<7, id: \.self) { day in
							AnimatedCalendarSquare(
								week: 0,
								day: day,
								waveOrigin: waveOrigin,
								trigger: trigger,
								heatmapColor: miniCalendarColor(for: day, intensities: miniCalendarIntensities, habitColor: habit.displayColor)
							)
							.onTapGesture {
								waveOrigin = CGPoint(x: 0, y: Double(day))
								trigger += 1
								HapticManager.shared.playWaveBounce()
							}
						}
					}
				}
				.frame(width: 80)
				.overlay(
					// Add subtle glow effect when wave is active
					RoundedRectangle(cornerRadius: 8)
						.stroke(habit.displayColor.opacity(0.3), lineWidth: 1)
						.opacity(trigger > 0 ? 0.8 : 0.0)
						.animation(.easeInOut(duration: 0.3), value: trigger)
				)
				
				// Completion Button
				Button(action: {
					// Trigger wave animation when completing habit
					// Set wave origin to today's position (day 6, which is the rightmost day)
					waveOrigin = CGPoint(x: 0, y: 6)
					trigger += 1
					HapticManager.shared.playWaveBounce()
					onToggle()
				}) {
					ZStack {
						Circle()
							.fill(isCompleted ? habit.displayColor : Color(.systemGray5))
							.frame(width: 32, height: 32)
						
						if isCompleted {
							Image(systemName: "checkmark")
								.font(.caption)
								.fontWeight(.bold)
								.foregroundColor(.white)
						}
					}
				}
				.buttonStyle(PlainButtonStyle())
				.scaleEffect(isCompleted ? 1.1 : 1.0)
				.animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCompleted)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(colorScheme == .light ? Color.white : Color(.secondarySystemBackground))
					.overlay(
						RoundedRectangle(cornerRadius: 16)
							.stroke(Color(.separator), lineWidth: 0.5)
					)
					.shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 2)
			)
		}
		.buttonStyle(PlainButtonStyle())
	}

    private func progressText(todayTotal: Int) -> String {
        if habit.usesTargetGoal {
            return "\(todayTotal)/\(max(1, habit.target))"
        }
        return todayTotal > 0 ? "Done today" : "Not done yet"
    }

    private func recentMiniCalendarIntensities() -> [Double] {
        let totals = habitStore.getRecentDailyTotals(for: habit.id, days: 7)
        return totals.map { total in
            if habit.usesTargetGoal {
                return min(1.0, Double(total) / Double(max(1, habit.target)))
            }
            return total > 0 ? 1.0 : 0.0
        }
    }

    private func miniCalendarColor(for day: Int, intensities: [Double], habitColor: Color) -> Color {
        guard day >= 0, day < intensities.count else { return HeatmapColorUtility.noDataTileColor }
        let intensity = intensities[day]
        return intensity > 0 ? habitColor.opacity(HeatmapColorUtility.clampedProgressOpacity(intensity)) : HeatmapColorUtility.noDataTileColor
    }
}

fileprivate func calculateDistance(point1: CGPoint, point2: CGPoint) -> Double {
	return hypot(point2.x - point1.x, point2.y - point1.y)
}

struct AnimatedCalendarSquare: View {
	let week: Int
	let day: Int
	let waveOrigin: CGPoint
	let trigger: Int
	let heatmapColor: Color
	let size: CGFloat
	
	init(week: Int, day: Int, waveOrigin: CGPoint, trigger: Int, heatmapColor: Color, size: CGFloat = 12) {
		self.week = week
		self.day = day
		self.waveOrigin = waveOrigin
		self.trigger = trigger
		self.heatmapColor = heatmapColor
		self.size = size
	}

	var body: some View {
		let cellCoordinates = CGPoint(x: Double(week), y: Double(day))
		let originDistance = calculateDistance(point1: waveOrigin, point2: cellCoordinates)
		
		let delay = 0.04 * originDistance
		let initialShrink = 0.55
		let overshoot = 1.22
		
		let isWaveOrigin = waveOrigin == cellCoordinates
		
		ZStack {
			RoundedRectangle(cornerRadius: max(1, size * 0.17))
				.fill(Color.clear)
				.frame(width: size, height: size)
			
			RoundedRectangle(cornerRadius: max(1, size * 0.17))
				.fill(heatmapColor)
				.frame(width: size, height: size)
			
			if isWaveOrigin && trigger > 0 {
				RoundedRectangle(cornerRadius: max(1, size * 0.17))
					.stroke(heatmapColor, lineWidth: 2)
					.frame(width: size, height: size)
					.scaleEffect(1.18)
					.opacity(0.9)
			}
		}
		.keyframeAnimator(initialValue: 1.0, trigger: trigger) { content, scale in
			content
				.scaleEffect(scale)
		} keyframes: { _ in
			KeyframeTrack {
				LinearKeyframe(1.0, duration: delay)
				MoveKeyframe(initialShrink)
				SpringKeyframe(overshoot, duration: 0.24, spring: .snappy(duration: 0.24))
				SpringKeyframe(1.0, duration: 0.26, spring: .snappy(duration: 0.26))
			}
		}
	}
}

struct HabitCardCompact: View {
	let habit: Habit
	let isCompleted: Bool
	let onToggle: () -> Void
	
	@Environment(HabitStore.self) private var habitStore
	@Environment(\.colorScheme) private var colorScheme
	@State private var trigger: Int = 0
	@State private var waveOrigin: CGPoint = CGPoint(x: 2, y: 3)
	
	var body: some View {
        let miniCalendarIntensities = recentMiniCalendarIntensities()
		HStack(spacing: 12) {
			// Icon
			ZStack {
				Circle()
					.fill(habit.displayColor.opacity(0.2))
					.frame(width: 36, height: 36)
				
				Image(systemName: "star.fill")
					.font(.subheadline)
					.foregroundColor(habit.displayColor)
			}
			
			// Habit Name
					Text(habit.name)
						.font(.body)
						.foregroundColor(.primary)
						.lineLimit(2)
			
			Spacer()
			
			// Mini Calendar with Wave Animation
			VStack(spacing: 2) {
				// Week overview (7 days) - smaller for compact view
				HStack(spacing: 1) {
					ForEach(0..<7, id: \.self) { day in
						AnimatedCalendarSquare(
							week: 0,
							day: day,
							waveOrigin: waveOrigin,
							trigger: trigger,
							heatmapColor: miniCalendarColor(for: day, intensities: miniCalendarIntensities, habitColor: habit.displayColor),
							size: 8
						)
						.onTapGesture {
							waveOrigin = CGPoint(x: 0, y: Double(day))
							trigger += 1
							HapticManager.shared.playWaveBounce()
						}
					}
				}
			}
			.frame(width: 60)
			.overlay(
				// Add subtle glow effect when wave is active
				RoundedRectangle(cornerRadius: 6)
					.stroke(habit.displayColor.opacity(0.3), lineWidth: 1)
					.opacity(trigger > 0 ? 0.8 : 0.0)
					.animation(.easeInOut(duration: 0.3), value: trigger)
			)
			
			// Streak
			if habit.streak > 0 {
				HStack(spacing: 2) {
					Image(systemName: "flame.fill")
						.font(.caption2)
						.foregroundColor(.orange)
					
					Text("\(habit.streak)")
						.font(.caption2)
						.fontWeight(.semibold)
						.foregroundColor(.secondary)
				}
			}
			
			// Completion Button
			Button(action: {
				// Trigger wave animation when completing habit
				// Set wave origin to today's position (day 6, which is the rightmost day)
				waveOrigin = CGPoint(x: 0, y: 6)
				trigger += 1
				HapticManager.shared.playWaveBounce()
				onToggle()
			}) {
				ZStack {
					Circle()
						.fill(isCompleted ? habit.displayColor : Color(.systemGray5))
						.frame(width: 28, height: 28)
					
					if isCompleted {
						Image(systemName: "checkmark")
							.font(.caption2)
							.fontWeight(.bold)
							.foregroundColor(.white)
					}
				}
			}
			.buttonStyle(PlainButtonStyle())
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.background(
			RoundedRectangle(cornerRadius: 14)
				.fill(colorScheme == .light ? Color.white : Color(.secondarySystemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: 14)
						.stroke(Color(.separator), lineWidth: 0.5)
				)
		)
	}

    private func recentMiniCalendarIntensities() -> [Double] {
        let totals = habitStore.getRecentDailyTotals(for: habit.id, days: 7)
        return totals.map { total in
            if habit.usesTargetGoal {
                return min(1.0, Double(total) / Double(max(1, habit.target)))
            }
            return total > 0 ? 1.0 : 0.0
        }
    }

    private func miniCalendarColor(for day: Int, intensities: [Double], habitColor: Color) -> Color {
        guard day >= 0, day < intensities.count else { return HeatmapColorUtility.noDataTileColor }
        let intensity = intensities[day]
        return intensity > 0 ? habitColor.opacity(HeatmapColorUtility.clampedProgressOpacity(intensity)) : HeatmapColorUtility.noDataTileColor
    }
}

struct HabitCardGrid: View {
	let habit: Habit
	let isCompleted: Bool
	let onToggle: () -> Void
	let onTap: () -> Void
	
	@Environment(HabitStore.self) private var habitStore
	@Environment(\.colorScheme) private var colorScheme
	@State private var trigger: Int = 0
	@State private var waveOrigin: CGPoint = CGPoint(x: 3, y: 3)
	
	var body: some View {
        let miniCalendarIntensities = recentMiniCalendarIntensities()
		Button(action: onTap) {
			VStack(spacing: 12) {
				// Icon
				ZStack {
					Circle()
						.fill(habit.displayColor.opacity(0.2))
						.frame(width: 56, height: 56)
					
					Image(systemName: "star.fill")
						.font(.title2)
						.foregroundColor(habit.displayColor)
				}
				
				// Habit Name
					Text(habit.name)
						.font(.body)
						.foregroundColor(.primary)
						.lineLimit(2)
						.multilineTextAlignment(.center)
				
				// Mini Calendar with Wave Animation
				VStack(spacing: 4) {
					// Week overview (7 days)
					HStack(spacing: 2) {
						ForEach(0..<7, id: \.self) { day in
							AnimatedCalendarSquare(
								week: 0,
								day: day,
								waveOrigin: waveOrigin,
								trigger: trigger,
								heatmapColor: miniCalendarColor(for: day, intensities: miniCalendarIntensities, habitColor: habit.displayColor)
							)
							.onTapGesture {
								waveOrigin = CGPoint(x: 0, y: Double(day))
								trigger += 1
								HapticManager.shared.playWaveBounce()
							}
						}
					}
				}
				.frame(width: 80)
				
				// Streak
				if habit.streak > 0 {
					HStack(spacing: 4) {
						Image(systemName: "flame.fill")
							.font(.caption2)
							.foregroundColor(.orange)
						
						Text("\(habit.streak)")
							.font(.caption2)
							.fontWeight(.semibold)
							.foregroundColor(.secondary)
					}
				}
				
				// Completion Button
				Button(action: {
					// Trigger wave animation when completing habit
					// Set wave origin to today's position (day 6, which is the rightmost day)
					waveOrigin = CGPoint(x: 0, y: 6)
					trigger += 1
					HapticManager.shared.playWaveBounce()
					onToggle()
				}) {
					ZStack {
						Circle()
							.fill(isCompleted ? habit.displayColor : Color(.systemGray5))
							.frame(width: 32, height: 32)
						
						if isCompleted {
							Image(systemName: "checkmark")
								.font(.caption)
								.fontWeight(.bold)
								.foregroundColor(.white)
						}
					}
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(12)
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(colorScheme == .light ? Color.white : Color(.secondarySystemBackground))
					.overlay(
						RoundedRectangle(cornerRadius: 16)
							.stroke(Color(.separator), lineWidth: 0.5)
					)
					.shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 2)
			)
		}
		.buttonStyle(PlainButtonStyle())
	}

    private func recentMiniCalendarIntensities() -> [Double] {
        let totals = habitStore.getRecentDailyTotals(for: habit.id, days: 7)
        return totals.map { total in
            if habit.usesTargetGoal {
                return min(1.0, Double(total) / Double(max(1, habit.target)))
            }
            return total > 0 ? 1.0 : 0.0
        }
    }

    private func miniCalendarColor(for day: Int, intensities: [Double], habitColor: Color) -> Color {
        guard day >= 0, day < intensities.count else { return HeatmapColorUtility.noDataTileColor }
        let intensity = intensities[day]
        return intensity > 0 ? habitColor.opacity(HeatmapColorUtility.clampedProgressOpacity(intensity)) : HeatmapColorUtility.noDataTileColor
    }
}
