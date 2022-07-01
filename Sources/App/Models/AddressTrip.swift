//
//  AddressTrip.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

final class AddressTrip: Model, Content {
    // Name of the table
    static let schema: String = "address_trip"
    
    // Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    // Fields
    @Parent(key: "address_id")
    var address: Address
    
    @Parent(key: "trip_id")
    var trip: Trip
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil, trip: Trip, address: Address) throws {
        self.id = id
        self.$trip.id = try trip.requireID()
        self.$address.id = try address.requireID()
    }
}
