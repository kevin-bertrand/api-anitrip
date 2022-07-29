//
//  AddressController.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct AddressController {
    // MARK: Utilities functions
    // MARK: Public
    /// Check if an address is saved. If not save it.
    func create(_ address: Address?, for req: Request) async throws -> Address? {
        guard let address = address else { return nil }
        
        if let addressId = try await checkIfAddressExists(address, for: req) {
            return addressId
        }
        
        try await address.save(on: req.db)
        
        return try await checkIfAddressExists(address, for: req)
    }
    
    /// Return an address from its ID
    func getAddressFromId(_ id: UUID?, for req: Request) async throws -> Address? {
        return try await Address.find(id, on: req.db)
    }
    
    // MARK: Private
    /// Check if the address already exists
    private func checkIfAddressExists(_ address: Address, for req: Request) async throws -> Address? {
        return try await Address.query(on: req.db)
            .filter(\.$roadName == address.roadName)
            .filter(\.$streetNumber == address.streetNumber)
            .filter(\.$city == address.city)
            .first()
    }
}
