//  Notification+Extensions.swift
//  Feather
//
//  Created by AI on 13.07.2025.
//

import Foundation

extension Notification.Name {
    /// Posted when a new application has been imported into the local library.
    /// The notification `object` contains the imported app UUID as a `String`.
    static let featherDidImportApp = Notification.Name("Feather.didImportApp")
}