//
//  CreateDevice.swift
//  
//
//  Created by Kevin Bertrand on 21/07/2022.
//

import Fluent
import Vapor

struct CreateDevice: AsyncMigration {
    // Create DB
    func prepare(on database: Database) async throws {
        try await database.schema(Device.schema)
            .id()
            .field("device_id", .string, .required)
            .field("user_id", .uuid, .required, .references(User.schema, "id"))
            .create()
    }
    
    // Deleted DB
    func revert(on database: Database) async throws {
        try await database.schema(Device.schema).delete()
    }
}

