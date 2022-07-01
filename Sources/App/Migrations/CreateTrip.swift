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
            .field("date", .datetime, .required)
            .field("missions", .array(of: .string), .required)
            .field("comment", .string)
            .field("total_distance", .double, .required)
            .unique(on: .id)
            .create()
    }
    
    // Deleted DB
    func revert(on database: Database) async throws {
        try await database.schema(Trip.schema).delete()
    }
}

