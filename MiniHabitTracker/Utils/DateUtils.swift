import Foundation

enum DateUtils {
	static func localizedDayAbbreviation(dayIndex: Int) -> String {
		let calendar = Calendar.current
		let formatter = DateFormatter()
		formatter.locale = Locale.current
		formatter.dateFormat = "EEE"
		// January 7, 2024 was a Sunday; use it as an anchor to ensure Sunday = 0
		let sunday = calendar.date(from: DateComponents(year: 2024, month: 1, day: 7))!
		let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: sunday)!
		return formatter.string(from: targetDate)
	}
}


