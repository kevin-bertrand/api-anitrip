//
//  Double.swift
//  
//
//  Created by Kevin Bertrand on 14/09/2022.
//

import Foundation
extension Double {
    /// Truncate a double to a two digits number
    var twoDigitPrecision: String {
        return String(format: "%.2f", self)
    }
}
