//
//  Date.swift
//  
//
//  Created by Kevin Bertrand on 08/07/2022.
//

import Foundation

extension Date {
    /// Calculate a date with a delta
    func getFormattedDateWithDelta(format: String, delta: Double) -> String {
        let dateformat = DateFormatter()
        dateformat.dateFormat = format
        let date = self
        return dateformat.string(from: (date-delta*84600))
    }
    
    /// Get the date at the format dd/MM/yyyy
    var dateOnly: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: self)
    }
}
