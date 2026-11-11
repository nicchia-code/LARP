import Foundation
import SwiftUI

/// The language of the interface: Italian or English. Italian when the language of the Mac (or the
/// one chosen for LARP in System Settings) is Italian, English in every other case.
enum AppLanguage: String, Sendable, CaseIterable {
    case italian = "it"
    case english = "en"

    /// For tests: the language `current` answers inside the operation.
    @TaskLocal static var override: AppLanguage?

    /// The language of the interface now: the system one, resolved once (changing the language of
    /// an app in System Settings relaunches it).
    static var current: AppLanguage {
        override ?? system
    }

    private static let system = resolve(preferred: Locale.preferredLanguages)

    /// The first of the preferred languages that is Italian or English; English when none is.
    static func resolve(preferred: [String]) -> AppLanguage {
        for identifier in preferred {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "it": return .italian
            case "en": return .english
            default: continue
            }
        }
        return .english
    }

    /// The locale of dates, times and names in this language.
    var locale: Locale {
        Locale(identifier: self == .italian ? "it_IT" : "en_US")
    }

    /// The bundle holding the texts of this language.
    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"), let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}

/// The texts built in code. The key is the Italian text, as in the views, and the String Catalog
/// (`Localizable.xcstrings`) holds the English one.
enum L10n {
    static func string(_ key: String, language: AppLanguage = .current) -> String {
        language.bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// A text with `%@`, `%d`, `%lld` placeholders filled in; numbers are written plainly, with no
    /// grouping (a year is `2026`, not `2,026`).
    static func format(_ key: String, _ arguments: CVarArg..., language: AppLanguage = .current) -> String {
        String(format: string(key, language: language), arguments: arguments)
    }

    /// `one` for 1, `other` otherwise; both keys hold a `%lld` for the count.
    static func count(_ number: Int, one: String, other: String, language: AppLanguage = .current) -> String {
        format(number == 1 ? one : other, number, language: language)
    }
}

extension View {
    /// The environment every LARP window and panel is given: the locale of the interface language,
    /// so that the texts of the views are looked up in it.
    func larpEnvironment() -> some View {
        environment(\.locale, AppLanguage.current.locale)
    }
}
