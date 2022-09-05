//
//  Authentication.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

extension User: ModelAuthenticatable {
    static var usernameKey = \User.$email
    static var passwordHashKey = \User.$password
    
    /// Verify the password entered by the user with the saved password
    func verify(password: String) throws -> Bool {
        return try Bcrypt.verify(password, created: self.password)
    }
    
    /// Generate a token
    func generateToken() throws -> UserToken {
        return try UserToken(value: [UInt8].random(count: 16).base64, userID: self.requireID())
    }
}

extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user
    
    /// Check if the token is valid
    var isValid: Bool {
        true
    }
}
