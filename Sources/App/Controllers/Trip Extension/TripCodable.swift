//
//  TripCodable.swift
//  
//
//  Created by Kevin Bertrand on 04/07/2022.
//

import Foundation

extension Trip {
    struct Update: Codable {
        let id: UUID
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
    
    struct News: Codable {
        let distanceThisWeek: Double
        let numberOfTripThisWeek: Int
        let distanceThisYear: Double
        let numberOfTripThisYear: Int
        let distancePercentSinceLastYear: Double
        let distancePercentSinceLastWeek: Double
        let numberTripPercentSinceLastYear: Double
        let numberTripPercentSinceLastWeek: Double
    }
    
    struct ListFilter: Codable {
        let userID: UUID
        let startDate: String
        let endDate: String
    }
    
    struct TripToExport: Codable {
        let userLastname: String
        let userFirstname: String
        let userPhone: String
        let userEmail: String
        let startDate: String
        let endDate: String
        var totalDistance: Double
        var trips: [Informations]
    }
}
