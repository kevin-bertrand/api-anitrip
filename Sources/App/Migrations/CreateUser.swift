//
//  CreateUser.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct CreateUser: AsyncMigration {
    // Create DB
    func prepare(on database: Database) async throws {
        let gender = try await database.enum("gender")
            .case(Gender.man.rawValue)
            .case(Gender.woman.rawValue)
            .case(Gender.notDetermined.rawValue)
            .create()
        
        let position = try await database.enum("position")
            .case(Position.administrator.rawValue)
            .case(Position.user.rawValue)
            .create()
        
        try await database.schema(User.schema)
            .id()
            .field("firstname", .string, .required)
            .field("lastname", .string, .required)
            .field("email", .string, .required)
            .field("phone_number", .string, .required)
            .field("gender", gender, .required)
            .field("password", .string, .required)
            .field("position", position , .required)
            .field("misions", .array(of: .string), .required)
            .field("is_active", .bool, .required)
            .field("address_id", .uuid, .required, .references(Address.schema, "id"))
            .unique(on: "email")
            .create()
    }
    
    // Deleted DB
    func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
}

