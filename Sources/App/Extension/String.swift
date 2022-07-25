//
//  String.swift
//  
//
//  Created by Kevin Bertrand on 25/07/2022.
//

import Foundation

extension String {
    /// Convert a string into a date
    var toDate: Date? {
        var date: Date?
        
        if let convertedDate = ISO8601DateFormatter().date(from: self) {
            date = convertedDate
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            date = formatter.date(from: self)
        }
        return date
    }
}
