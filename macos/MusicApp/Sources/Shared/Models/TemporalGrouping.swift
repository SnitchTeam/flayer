import Foundation

struct TemporalGroup<T>: Identifiable {
    let id: String
    let label: String
    let shortLabel: String
    var items: [T]
}

/// Groups pre-sorted (by date DESC) items into temporal sections.
func groupByTimePeriod<T>(_ items: [(T, Date)]) -> [TemporalGroup<T>] {
    let calendar = Calendar.current
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
    let currentYear = calendar.component(.year, from: now)

    let monthFormatter = DateFormatter()
    monthFormatter.locale = Lang.monthLocale
    monthFormatter.dateFormat = "MMMM yyyy"

    let shortMonthFormatter = DateFormatter()
    shortMonthFormatter.locale = Lang.monthLocale
    shortMonthFormatter.dateFormat = "MMM"

    var result: [TemporalGroup<T>] = []
    var lastKey = ""

    for (item, date) in items {
        let key: String
        let label: String
        let shortLabel: String

        if date >= startOfToday {
            key = "today"
            label = Lang.today
            shortLabel = Lang.todayShort
        } else if date >= sevenDaysAgo {
            key = "week"
            label = Lang.thisWeek
            shortLabel = Lang.thisWeekShort
        } else if date >= startOfMonth {
            key = "month"
            label = Lang.thisMonth
            shortLabel = Lang.thisMonthShort
        } else {
            let comps = calendar.dateComponents([.year, .month], from: date)
            let year = comps.year ?? currentYear

            if year == currentYear {
                key = "m-\(comps.month ?? 1)"
                label = monthFormatter.string(from: date).capitalized
                shortLabel = shortMonthFormatter.string(from: date).capitalized
            } else {
                key = "y-\(year)"
                label = "\(year)"
                shortLabel = String(format: "'%02d", year % 100)
            }
        }

        if key == lastKey, !result.isEmpty {
            result[result.count - 1].items.append(item)
        } else {
            result.append(TemporalGroup(id: key, label: label, shortLabel: shortLabel, items: [item]))
            lastKey = key
        }
    }

    return result
}
