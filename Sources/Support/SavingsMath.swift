import Foundation

struct GoalPlan: Equatable {
    let workdays: Int
    let dailySavings: Int
    let minimumDailyGross: Int
    let endDate: Date
}

enum SavingsMath {
    /// Counts the selected working days from the start date, inclusive,
    /// to the same calendar date a number of months later, exclusive.
    /// Workweeks begin on Wednesday: five days means Wednesday through Sunday.
    static func workdays(
        start: Date,
        months: Int,
        daysPerWeek: Int,
        calendar: Calendar = .current
    ) -> Int {
        // Noon keeps the day count stable when Chile's DST skips midnight.
        guard (1...7).contains(daysPerWeek),
              let period = period(start: start, months: months, calendar: calendar),
              let countStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: period.start),
              let countEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: period.end),
              let dayCount = calendar.dateComponents(
                [.day], from: countStart, to: countEnd
              ).day,
              dayCount > 0 else {
            return 0
        }

        let (wholeWeekDays, overflow) = (dayCount / 7)
            .multipliedReportingOverflow(by: daysPerWeek)
        guard !overflow else { return 0 }

        let wednesdayBasedWeekday = (calendar.component(.weekday, from: period.start) + 3) % 7
        let remainingWorkdays = (0..<(dayCount % 7)).reduce(0) { result, offset in
            result + ((wednesdayBasedWeekday + offset) % 7 < daysPerWeek ? 1 : 0)
        }
        let (total, additionOverflow) = wholeWeekDays.addingReportingOverflow(remainingWorkdays)
        return additionOverflow ? 0 : total
    }

    static func plan(
        targetAmount: Int,
        start: Date,
        months: Int,
        daysPerWeek: Int,
        dailyFuelEstimate: Int,
        calendar: Calendar = .current
    ) -> GoalPlan? {
        guard targetAmount > 0,
              dailyFuelEstimate >= 0,
              let period = period(start: start, months: months, calendar: calendar) else {
            return nil
        }

        let totalWorkdays = workdays(
            start: period.start,
            months: months,
            daysPerWeek: daysPerWeek,
            calendar: calendar
        )
        guard totalWorkdays > 0 else { return nil }

        // Divide before rounding to avoid overflowing with target + days - 1.
        let dailySavings = targetAmount / totalWorkdays
            + (targetAmount % totalWorkdays == 0 ? 0 : 1)
        let (minimumGross, overflow) = dailySavings.addingReportingOverflow(dailyFuelEstimate)
        guard !overflow else { return nil }

        return GoalPlan(
            workdays: totalWorkdays,
            dailySavings: dailySavings,
            minimumDailyGross: minimumGross,
            endDate: period.end
        )
    }

    private static func period(
        start: Date,
        months: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date)? {
        guard months > 0, start.timeIntervalSinceReferenceDate.isFinite else { return nil }
        let startDay = calendar.startOfDay(for: start)
        guard let candidateEnd = calendar.date(byAdding: .month, value: months, to: startDay),
              candidateEnd.timeIntervalSinceReferenceDate.isFinite else {
            return nil
        }
        let endDay = calendar.startOfDay(for: candidateEnd)
        guard endDay > startDay else { return nil }
        return (startDay, endDay)
    }
}

enum CLPAmount {
    static let maximum = 999_999_999

    /// Accepts whole pesos, for example 1600, 1.600, or $ 1.600.
    /// Decimal separators, negative values and malformed groups are rejected.
    static func parse(_ text: String) -> Int? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("$") {
            value.removeFirst()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !value.isEmpty else { return nil }

        let groups = value.split(separator: ".", omittingEmptySubsequences: false)
        guard groups.allSatisfy({ group in
            !group.isEmpty && group.utf8.allSatisfy { (48...57).contains($0) }
        }) else {
            return nil
        }

        if groups.count > 1 {
            guard let first = groups.first,
                  (1...3).contains(first.count),
                  first.first != "0",
                  groups.dropFirst().allSatisfy({ $0.count == 3 }) else {
                return nil
            }
        }

        guard let amount = Int(groups.joined()), amount <= maximum else { return nil }
        return amount
    }
}
