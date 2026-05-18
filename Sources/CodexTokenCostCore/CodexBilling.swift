import Foundation

public enum CodexBilling {
    public static let gptPlusMonthlyCost: Double =
        BillingPlanCatalog.preset(id: "chatgpt-plus")?.normalizedMonthlyUSD ?? 20
}
