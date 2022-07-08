//
//  CreateTrip.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct CreateTrip: AsyncMigration {
    // Create DB
    func prepare(on database: Database) async throws {
        try await database.schema(Trip.schema)
            .id()
            .field("date", .string, .required)
            .field("missions", .array(of: .string), .required)
            .field("comment", .string)
            .field("total_distance", .double, .required)
            .field("user_id", .uuid, .required, .references(User.schema, "id"))
            .field("starting_address", .uuid, .required, .references(Address.schema, "id"))
            .field("ending_address", .uuid, .required, .references(Address.schema, "id"))
            .create()
    }
    
    // Deleted DB
    func revert(on database: Database) async throws {
        try await database.schema(Trip.schema).delete()
    }
}

