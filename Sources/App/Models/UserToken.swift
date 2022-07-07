//
//  UserToken.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

final class UserToken: Model, Content {
    // Name of the table
    static let schema: String = "user_token"
    
    // Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    // Fields
//    @Field(key: "creation_date")
//    var creationDate: Date
    
    @Field(key: "value")
    var value: String
    
    @Parent(key: "user_id")
    var user: User
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil, value: String, userID: User.IDValue) {
        self.id = id
//        self.creationDate = Date.now
        self.value = value
        self.$user.id = userID
    }
}
