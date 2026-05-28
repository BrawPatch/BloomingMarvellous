import Foundation
import CoreText
import os.log

// MARK: - BMFonts
//
// Registers the Fredoka + Nunito font files that ship inside the
// `BloomingMarvellous` SPM bundle so SwiftUI / UIKit can render
// `.custom("Fredoka-SemiBold", size: …)` etc. without an Info.plist
// `UIAppFonts` entry — the iOS Xcode target consumes us as a library
// and doesn't otherwise see the resources.
//
// Call `BMFonts.register()` once at app launch (e.g. in the App's
// initialiser). Re-registering is harmless — CTFontManager is idempotent
// for the same URL within the same scope.

public enum BMFonts {

    private static let names: [String] = [
        "Fredoka-Regular",
        "Fredoka-Medium",
        "Fredoka-SemiBold",
        "Fredoka-Bold",
        "Nunito-Regular",
        "Nunito-SemiBold",
        "Nunito-Bold",
    ]

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
        category: "BMFonts"
    )

    public static func register() {
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
                logger.warning("Font file missing in bundle: \(name).ttf")
                continue
            }
            var errorRef: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef)
            if !ok {
                // errorAlreadyRegistered (code 105) is fine — re-registers don't fail loudly.
                let code = (errorRef?.takeRetainedValue() as Error?).map { ($0 as NSError).code } ?? -1
                if code != 105 {
                    logger.warning("CTFontManagerRegisterFontsForURL failed for \(name): code=\(code)")
                }
            }
        }
    }
}
