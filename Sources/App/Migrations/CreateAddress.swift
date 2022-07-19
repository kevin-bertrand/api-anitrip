//
//  CreateAddress.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct CreateAddress: AsyncMigration {
    // Create DB
    func prepare(on database: Database) async throws {
        try await database.schema(Address.schema)
            .id()
            .field("road_name", .string, .required)
            .field("street_number", .string, .required)
            .field("complement", .string)
            .field("zip_code", .string, .required)
            .field("city", .string, .required)
            .field("country", .string, .required)
            .create()
    }
    
    // Deleted DB
    func revert(on database: Database) async throws {
        try await database.schema(Address.schema).delete()
    }
}

