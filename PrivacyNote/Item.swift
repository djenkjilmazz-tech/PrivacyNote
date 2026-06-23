//
//  Item.swift
//  PrivacyNote
//
//  Created by Cenk Yilmaz on 23.06.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
