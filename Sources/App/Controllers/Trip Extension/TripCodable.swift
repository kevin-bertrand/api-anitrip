//
//  TripCodable.swift
//  
//
//  Created by Kevin Bertrand on 04/07/2022.
//

import Foundation

extension Trip {
    struct Create: Codable {
        let date: String
        let missions: [String]
        let comment: String?
        let totalDistance: Double
        let startingAddress: Address
        let endingAddress: Address
    }
    
    struct Informations: Codable {
        let id: UUID?
        let date: String
        let missions: [String]
        let comment: String?
        let totalDistance: Double
        let startingAddress: Address?
        let endingAddress: Address?
    }
    
    struct ChartInfo: Codable {
        let date: String
        let distance: Double
        let numberOfTrip: Int
    }
    
    struct ThisWeekInfo: Codable {
        let distance: Double
        let numberOfTrip: Int
    }
}
