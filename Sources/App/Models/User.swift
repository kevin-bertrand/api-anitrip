//
//  User.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

final class User: Model, Content {
    // Name of the table
    static let schema: String = "user"
    
    // Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    // Fields
    @Field(key: "firstname")
    var firstname: String
    
    @Field(key: "lastname")
    var lastname: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "phone_number")
    var phoneNumber: String
    
    @Enum(key: "gender")
    var gender: Gender
    
    @Field(key: "password")
    var password: String
    
    @Enum(key: "position")
    var position: Position
    
    @Field(key: "missions")
    var missions: [String]
    
    @Field(key: "is_active")
    var isActive: Bool
    
    @Field(key: "is_deleted")
    var isDeleted: Bool
    
    @OptionalParent(key: "address_id")
    var address: Address?
    
    @Children(for: \.$user)
    var devices: [Device]
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil,
         email: String,
         password: String) {
        self.id = id
        self.firstname = ""
        self.lastname = ""
        self.email = email
        self.phoneNumber = ""
        self.gender = .notDetermined
        self.password = password
        self.position = .user
        self.missions = []
        self.isActive = false
        self.isDeleted = false
        self.$address.id = nil
    }
}
