//
//  Trip.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

final class Trip: Model, Content {
    // Name of the table
    static let schema: String = "trip"
    
    // Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    // Fields
    @Field(key: "date")
    var date: Date
    
    @Field(key: "missions")
    var missions: [String]
    
    @OptionalField(key: "comment")
    var comment: String?
    
    @Field(key: "total_distance")
    var totalDistance: Double
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil, date: Date, missions: [String], comment: String?, totalDistance: Double) {
        self.id = id
        self.date = date
        self.missions = missions
        self.comment = comment
        self.totalDistance = totalDistance
    }
}
