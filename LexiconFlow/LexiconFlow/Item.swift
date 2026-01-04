//
//  Item.swift
//  LexiconFlow
//
//  Created by Fedir Saienko on 4.01.26.
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
