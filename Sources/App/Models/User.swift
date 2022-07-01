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
    
    @Field(key: "gender")
    var gender: Gender
    
    @Field(key: "password")
    var password: String
    
    @Field(key: "position")
    var position: Position
    
    @Field(key: "missions")
    var missions: [String]
    
    @Field(key: "is_active")
    var isActive: Bool
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil,
         firstname: String,
         lastname: String,
         email: String,
         phoneNumber: String,
         gender: Gender,
         password: String,
         position: Position,
         missions: [String],
         isActive: Bool) {
        self.id = id
        self.firstname = firstname
        self.lastname = lastname
        self.email = email
        self.phoneNumber = phoneNumber
        self.gender = gender
        self.password = password
        self.position = position
        self.missions = missions
        self.isActive = isActive
    }
}
