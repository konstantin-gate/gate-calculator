import Foundation
import SwiftUI

private let resourceBundle: Bundle = {
    Bundle.module
}()

internal func localizedString(_ key: String, comment: String) -> String {
    return NSLocalizedString(key, bundle: resourceBundle, comment: comment)
}
