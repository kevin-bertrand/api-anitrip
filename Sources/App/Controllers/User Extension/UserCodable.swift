//
//  UserCodable.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Foundation

extension User {
    struct Connected: Codable {
        let id: UUID?
        let firstname: String
        let lastname: String
        let email: String
        let phoneNumber: String
        let gender: Gender
        let position: Position
        let missions: [String]
        let address: Address?
        let token: String
    }
    
    struct Create: Codable {
        let email: String
        let password: String
        let passwordVerification: String
    }
    
    struct UpdatePosition: Codable {
        let email: String
        let position: Position
    }
    
    struct Update: Codable {
        let firstname: String
        let lastname: String
        let phoneNumber: String
        let gender: Gender
        let missions: [String]
        let address: Address?
        let password: String?
        let passwordVerification: String?
    }
    
    struct Informations: Codable {
        let firstname: String
        let lastname: String
        let email: String
        let phoneNumber: String
        let position: Position
        let gender: Gender
        let missions: [String]
        let address: Address?
    }
}
