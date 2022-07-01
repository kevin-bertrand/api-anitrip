//
//  CreateAddressTrip.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct CreateAddressTrip: AsyncMigration {
    // Create DB
    func prepare(on database: Database) async throws {
        try await database.schema(AddressTrip.schema)
            .id()
            .field("address_id", .uuid, .required, .references(Address.schema, "id"))
            .field("trip_id", .uuid, .required, .references(Trip.schema, "id"))
            .unique(on: "address_id", "trip_id")
            .create()
    }
    
    // Deleted DB
    func revert(on database: Database) async throws {
        try await database.schema(AddressTrip.schema).delete()
    }
}

