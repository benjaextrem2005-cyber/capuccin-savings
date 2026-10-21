import Foundation

struct DayTotals: Equatable {
    let gross: Int
    let fuel: Int
    let otherExpenses: Int
    var expenses: Int { addingClamped(fuel, otherExpenses) }
    var net: Int { gross - expenses }
}

struct GoalProgress: Equatable {
    let saved: Int
    let remaining: Int
    let fraction: Double
}

struct DailyTarget: Equatable {
    let date: Date
    let isToday: Bool
    let remainingWorkdays: Int
    let dailySavings: Int
    let fuelBudget: Int
    let otherExpenses: Int
    let minimumGross: Int
    let grossRecorded: Int
    let netRecorded: Int
    let remainingGross: Int
    let contributedToday: Int
    let remainingToSaveToday: Int
    let endDate: Date
}

struct WeekDayTotal: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let gross: Int
    let fuel: Int
    let otherExpenses: Int
    var expenses: Int { addingClamped(fuel, otherExpenses) }
    var net: Int { gross - expenses }
}

struct WeekSummary: Equatable {
    let start: Date
    let end: Date
    let days: [WeekDayTotal]
    let gross: Int
    let expenses: Int
    let net: Int
    let previousComparableNet: Int
    let comparisonDelta: Int
    let hasPreviousData: Bool
    let elapsedDays: Int
}

enum FinanceMath {
    static func day(
        _ date: Date,
        records: [DailyRecord],
        expenses: [VehicleExpense],
        calendar: Calendar = .current
    ) -> DayTotals {
        let matchingRecords = records.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let matchingExpenses = expenses.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return DayTotals(
            gross: nonnegativeSum(matchingRecords.map(\.grossIncome)),
            fuel: nonnegativeSum(matchingRecords.map(\.fuelExpense)),
            otherExpenses: nonnegativeSum(matchingExpenses.map(\.amount))
        )
    }

    static func progress(
        goal: SavingsGoal,
        contributions: [SavingsContribution],
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> GoalProgress {
        let cutoff = calendar.startOfDay(for: asOf)
        let saved = nonnegativeSum(contributions.filter {
            $0.goalID == goal.id && calendar.startOfDay(for: $0.date) <= cutoff
        }.map(\.amount))
        let target = max(0, goal.targetAmount)
        return GoalProgress(
            saved: saved,
            remaining: max(0, target - saved),
            fraction: target > 0 ? min(1, max(0, Double(saved) / Double(target))) : 0
        )
    }

    static func dailyTarget(
        goal: SavingsGoal,
        contributions: [SavingsContribution],
        records: [DailyRecord],
        expenses: [VehicleExpense],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyTarget? {
        guard now.timeIntervalSinceReferenceDate.isFinite,
              goal.dailyFuelEstimate >= 0,
              let originalPlan = SavingsMath.plan(
                targetAmount: goal.targetAmount,
                start: goal.startDate,
                months: goal.months,
                daysPerWeek: goal.daysPerWeek,
                dailyFuelEstimate: 0,
                calendar: calendar
              ),
              progress(goal: goal, contributions: contributions, asOf: now, calendar: calendar).remaining > 0 else {
            return nil
        }

        let today = calendar.startOfDay(for: now)
        var targetDate = max(today, calendar.startOfDay(for: goal.startDate))
        while targetDate < originalPlan.endDate && !isWorkday(targetDate, daysPerWeek: goal.daysPerWeek, calendar: calendar) {
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return nil }
            targetDate = calendar.startOfDay(for: nextDate)
        }
        guard targetDate < originalPlan.endDate else { return nil }

        let remainingDays = workdays(from: targetDate, until: originalPlan.endDate,
                                     daysPerWeek: goal.daysPerWeek, calendar: calendar)
        guard remainingDays > 0 else { return nil }

        let eligibleContributions = contributions.filter {
            $0.goalID == goal.id && calendar.startOfDay(for: $0.date) <= today
        }
        // Today's quota is fixed using savings before today. A contribution
        // reduces the amount left to set aside, without reducing the quota twice.
        let savedBeforeTarget = nonnegativeSum(eligibleContributions.filter {
            calendar.startOfDay(for: $0.date) < targetDate
        }.map(\.amount))
        let remainingBeforeTarget = max(0, goal.targetAmount - savedBeforeTarget)
        let quota = remainingBeforeTarget / remainingDays
            + (remainingBeforeTarget % remainingDays == 0 ? 0 : 1)

        let isToday = targetDate == today
        let actual = isToday ? day(targetDate, records: records, expenses: expenses, calendar: calendar)
            : DayTotals(gross: 0, fuel: 0, otherExpenses: 0)
        let hasDailyRecord = isToday && records.contains { calendar.isDate($0.date, inSameDayAs: targetDate) }
        let fuelBudget = hasDailyRecord ? actual.fuel : goal.dailyFuelEstimate
        let minimumGross = addingClamped(addingClamped(quota, fuelBudget), actual.otherExpenses)
        let contributedToday = isToday ? nonnegativeSum(eligibleContributions.filter {
            calendar.isDate($0.date, inSameDayAs: today)
        }.map(\.amount)) : 0

        return DailyTarget(
            date: targetDate,
            isToday: isToday,
            remainingWorkdays: remainingDays,
            dailySavings: quota,
            fuelBudget: fuelBudget,
            otherExpenses: actual.otherExpenses,
            minimumGross: minimumGross,
            grossRecorded: actual.gross,
            netRecorded: actual.net,
            remainingGross: max(0, minimumGross - actual.gross),
            contributedToday: contributedToday,
            remainingToSaveToday: isToday ? max(0, quota - contributedToday) : 0,
            endDate: originalPlan.endDate
        )
    }

    static func week(
        containing referenceDate: Date,
        records: [DailyRecord],
        expenses: [VehicleExpense],
        calendar: Calendar = .current
    ) -> WeekSummary {
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let dayOffset = (calendar.component(.weekday, from: referenceDay) + 3) % 7
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: referenceDay)!)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 7, to: start)!)
        let elapsedDays = dayOffset + 1
        let days: [WeekDayTotal] = (0..<7).map { offset in
            let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: start)!)
            let totals = offset < elapsedDays ? day(date, records: records, expenses: expenses, calendar: calendar)
                : DayTotals(gross: 0, fuel: 0, otherExpenses: 0)
            return WeekDayTotal(date: date, gross: totals.gross, fuel: totals.fuel, otherExpenses: totals.otherExpenses)
        }
        let gross = nonnegativeSum(days.map(\.gross))
        let totalExpenses = nonnegativeSum(days.map(\.expenses))
        let net = gross - totalExpenses

        let previousStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: start)!)
        let previousEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: elapsedDays, to: previousStart)!)
        let previousRecords = records.filter {
            let date = calendar.startOfDay(for: $0.date)
            return date >= previousStart && date < previousEnd
        }
        let previousExpenses = expenses.filter {
            let date = calendar.startOfDay(for: $0.date)
            return date >= previousStart && date < previousEnd
        }
        let previousGross = nonnegativeSum(previousRecords.map(\.grossIncome))
        let previousCosts = addingClamped(nonnegativeSum(previousRecords.map(\.fuelExpense)),
                                         nonnegativeSum(previousExpenses.map(\.amount)))
        let previousNet = previousGross - previousCosts

        return WeekSummary(
            start: start,
            end: end,
            days: days,
            gross: gross,
            expenses: totalExpenses,
            net: net,
            previousComparableNet: previousNet,
            comparisonDelta: addingClamped(net, -previousNet),
            hasPreviousData: !previousRecords.isEmpty || !previousExpenses.isEmpty,
            elapsedDays: elapsedDays
        )
    }

    private static func isWorkday(_ date: Date, daysPerWeek: Int, calendar: Calendar) -> Bool {
        (calendar.component(.weekday, from: date) + 3) % 7 < daysPerWeek
    }

    private static func workdays(from start: Date, until end: Date, daysPerWeek: Int, calendar: Calendar) -> Int {
        guard let startNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: start),
              let endNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: end),
              let dayCount = calendar.dateComponents([.day], from: startNoon, to: endNoon).day,
              dayCount > 0 else { return 0 }
        let firstWeekday = (calendar.component(.weekday, from: start) + 3) % 7
        let remainder = (0..<(dayCount % 7)).filter { (firstWeekday + $0) % 7 < daysPerWeek }.count
        return addingClamped((dayCount / 7) * daysPerWeek, remainder)
    }
}

private func nonnegativeSum(_ values: [Int]) -> Int {
    values.reduce(0) { addingClamped($0, max(0, $1)) }
}

private func addingClamped(_ lhs: Int, _ rhs: Int) -> Int {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    return overflow ? (rhs >= 0 ? Int.max : Int.min) : result
}
