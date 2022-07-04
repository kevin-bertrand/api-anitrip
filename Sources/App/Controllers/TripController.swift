//
//  TripController.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct TripController: RouteCollection {
    // Properties
    var addressController: AddressController
    
    /// Route initialisation
    func boot(routes: RoutesBuilder) throws {
        let tripGroup = routes.grouped("trip")
        let tokenGroup = tripGroup.grouped(UserToken.authenticator()).grouped(UserToken.guardMiddleware())
        tokenGroup.post(use: add)
        tokenGroup.patch(use: update)
        tokenGroup.get(":userID", use: getList)
    }
    
    // MARK: Routes functions
    private func add(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(Trip.Create.self)
        
        guard let userId = userAuth.id,
              let startingAddressId = try await addressController.create(receivedData.startingAddress, for: req),
              let endingAddressId = try await addressController.create(receivedData.endingAddress, for: req)  else {
            throw Abort(.unauthorized)
        }
    
        let newTrip = Trip(date: receivedData.date,
                           missions: receivedData.missions,
                           comment: receivedData.comment,
                           totalDistance: receivedData.totalDistance,
                           userID: userId,
                           startingAddressID: startingAddressId,
                           endingAddressID: endingAddressId)
        
        try await newTrip.save(on: req.db)
        
        return Response(status: .ok, version: .http3, headersNoUpdate: HTTPHeaders(), body: .empty)
    }
    
    private func update(req: Request) async throws -> Response {
        let receivedData = try req.content.decode(Trip.self)
        
        guard let tripId = receivedData.id,
              let startingAddressId = try await addressController.create(receivedData.startingAddress, for: req),
              let endingAddressId = try await addressController.create(receivedData.endingAddress, for: req)  else {
            throw Abort(.unauthorized)
        }
        
        try await Trip.query(on: req.db)
            .filter(\.$id == tripId)
            .set(\.$date, to: receivedData.date)
            .set(\.$missions, to: receivedData.missions)
            .set(\.$totalDistance, to: receivedData.totalDistance)
            .set(\.$startingAddress.$id, to: startingAddressId)
            .set(\.$endingAddress.$id, to: endingAddressId)
            .set(\.$comment, to: receivedData.comment)
            .update()
        
        return Response(status: .ok, version: .http3, headersNoUpdate: HTTPHeaders(), body: .empty)
    }
    
    private func getList(req: Request) async throws -> Response {
        guard let userId = UUID(uuidString: req.parameters.get("userID") ?? "nul ") else {
            throw Abort(.notFound)
        }
        
        let trips = try await Trip.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()
        
        return Response(status: .ok, version: .http3, headersNoUpdate: HTTPHeaders(), body: .init(data: try JSONEncoder().encode(trips)))
    }
    
    // MARK: Utilities functions
    private func getUserAuthFor(_ req: Request) throws -> User {
        return try req.auth.require(User.self)
    }
}
