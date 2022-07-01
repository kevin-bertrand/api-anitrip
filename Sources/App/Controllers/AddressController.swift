//
//  AddressController.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct AddressController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        
    }
    
    // MARK: Routes functions
    
    
    // MARK: Utilities functions
    func create(_ address: Address, for req: Request) async throws -> UUID? {
        if let addressId = try await checkIfAddressExists(address, for: req) {
            return addressId
        }
        
        try await address.save(on: req.db)
        
        return try await checkIfAddressExists(address, for: req)
    }
    
    /// Check if the address already exists
    private func checkIfAddressExists(_ address: Address, for req: Request) async throws -> UUID? {        
        return try await Address.query(on: req.db)
            .filter(\.$roadName == address.roadName)
            .filter(\.$streetNumber == address.streetNumber)
            .filter(\.$city == address.city)
            .first()?.id
    }
}
