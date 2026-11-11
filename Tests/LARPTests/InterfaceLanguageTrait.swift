import Testing

@testable import LARP

/// Runs a test or a suite with the interface in a given language, whatever the language of the Mac.
struct InterfaceLanguageTrait: SuiteTrait, TestTrait, TestScoping {
    let language: AppLanguage
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        try await AppLanguage.$override.withValue(language) {
            try await function()
        }
    }
}

extension Trait where Self == InterfaceLanguageTrait {
    /// The interface in Italian: the texts the tests read are the Italian ones.
    static var italianInterface: Self { Self(language: .italian) }
    static var englishInterface: Self { Self(language: .english) }
}
