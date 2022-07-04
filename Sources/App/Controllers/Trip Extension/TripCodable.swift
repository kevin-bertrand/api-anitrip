//
//  TripCodable.swift
//  
//
//  Created by Kevin Bertrand on 04/07/2022.
//

import Foundation

extension Trip {
    struct Create: Codable {
        let date: Date
        let missions: [String]
        let comment: String?
        let totalDistance: Double
        let startingAddress: Address
        let endingAddress: Address
    }
}
