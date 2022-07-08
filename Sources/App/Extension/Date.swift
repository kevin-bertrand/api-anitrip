//
//  Date.swift
//  
//
//  Created by Kevin Bertrand on 08/07/2022.
//

import Foundation

extension Date {
    func getFormattedDateWithDelta(format: String, delta: Double) -> String {
        let dateformat = DateFormatter()
        dateformat.dateFormat = format
        let date = self
        return dateformat.string(from: (date-delta*84600))
    }
}
