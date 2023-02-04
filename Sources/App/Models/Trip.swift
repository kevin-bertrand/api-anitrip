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
    var date: String
    
    @Field(key: "missions")
    var missions: [String]
    
    @OptionalField(key: "comment")
    var comment: String?
    
    @Field(key: "total_distance")
    var totalDistance: Double
    
    @Field(key: "is_round_trip")
    var isRoundTrip: Bool
    
    @Parent(key: "starting_address")
    var startingAddress: Address
    
    @Parent(key: "ending_address")
    var endingAddress: Address
    
    @Parent(key: "user_id")
    var user: User
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil,
         date: String,
         missions: [String],
         comment: String?,
         totalDistance: Double,
         isRoundTrip: Bool,
         userID: User.IDValue,
         startingAddressID: Address.IDValue,
         endingAddressID: Address.IDValue) {
        self.id = id
        self.date = date
        self.missions = missions
        self.comment = comment
        self.totalDistance = totalDistance
        self.isRoundTrip = isRoundTrip
        self.$user.id = userID
        self.$startingAddress.id = startingAddressID
        self.$endingAddress.id = endingAddressID
    }
}
