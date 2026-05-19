import Foundation

public protocol BalanceChecker: Sendable {
    /// The provider this checker is responsible for.
    var providerKind: BalanceProviderKind { get }

    /// Fetches the current balance snapshot from the provider's API.
    /// - Parameter authToken: The API key or access token for authentication.
    /// - Returns: A `BalanceSnapshot` describing the current state.
    func fetch(authToken: String) async throws -> BalanceSnapshot
}
