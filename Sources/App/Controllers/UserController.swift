//
//  UserController.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct UserController: RouteCollection {
    // Properties
    var addressController: AddressController
    
    /// Route initialisation
    func boot(routes: RoutesBuilder) throws {
        let userGroup = routes.grouped("user")
        userGroup.post("create", use: create)
        
        let basicGroup = userGroup.grouped(User.authenticator()).grouped(User.guardMiddleware())
        basicGroup.post("login", use: login)
        
        let tokenGroup = userGroup.grouped(UserToken.authenticator()).grouped(UserToken.guardMiddleware())
        tokenGroup.patch("activate", ":userEmail", use: activate)
        tokenGroup.patch("delete", ":userEmail", use: delete)
        tokenGroup.patch("position", use: updatePosition)
        tokenGroup.patch(use: update)
        tokenGroup.get(use: getList)
    }
    
    // MARK: Routes functions
    /// Login function
    private func login(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        guard userAuth.isActive else {
            throw Abort(.unauthorized)
        }
        
        let token = try await generateToken(for: userAuth, in: req)
        let userInformations = User.Connected(firstname: userAuth.firstname,
                                              lastname: userAuth.lastname,
                                              email: userAuth.email,
                                              phoneNumber: userAuth.phoneNumber,
                                              gender: userAuth.gender,
                                              position: userAuth.position,
                                              missions: userAuth.missions,
                                              address: userAuth.address,
                                              token: token.value)
        return Response(status: .ok,
                        version: .http3,
                        headersNoUpdate: HTTPHeaders(),
                        body: .init(data: try JSONEncoder().encode(userInformations)))
    }
    
    /// Create new user
    private func create(req: Request) async throws -> Response {
        let receivedData = try req.content.decode(User.Create.self)
        guard receivedData.password == receivedData.passwordVerification else {
            throw Abort(.notAcceptable)
        }
        try await User(email: receivedData.email, password: try Bcrypt.hash(receivedData.password)).save(on: req.db)
        return Response(status: .created, version: .http3, headersNoUpdate: HTTPHeaders(), body: .empty)
    }
    
    /// Activate account
    private func activate(req: Request) async throws -> Response {
        guard (try req.auth.require(User.self)).position == .administrator else {
            throw Abort(.unauthorized)
        }
        
        guard let userEmailToActivate = req.parameters.get("userEmail"),
              try await User.query(on: req.db).filter(\.$email == userEmailToActivate).all().count == 1 else {
            throw Abort(.notFound)
        }
        
        try await User.query(on: req.db)
            .filter(\.$email == userEmailToActivate)
            .set(\.$isActive, to: true)
            .update()
        
        return Response(status: .accepted, version: .http3, headersNoUpdate: HTTPHeaders(), body: .empty)
    }
    
    /// Delete account
    private func delete(req: Request) async throws -> Response {
        guard (try req.auth.require(User.self)).position == .administrator else {
            throw Abort(.unauthorized)
        }
        
        guard let userEmailToDelete = req.parameters.get("userEmail"),
              try await User.query(on: req.db).filter(\.$email == userEmailToDelete).all().count == 1 else {
            throw Abort(.notFound)
        }
        
        try await User.query(on: req.db)
            .filter(\.$email == userEmailToDelete)
            .set(\.$isDeleted, to: true)
            .set(\.$isActive, to: true)
            .update()
        
        return Response(status: .accepted, version: .http3, headersNoUpdate: HTTPHeaders(), body: .empty)
    }
    
    /// Update position
    private func updatePosition(req: Request) async throws -> Response {
        guard (try req.auth.require(User.self)).position == .administrator else {
            throw Abort(.unauthorized)
        }
        
        let receivedData = try req.content.decode(User.UpdatePosition.self)
        
        guard try await User.query(on: req.db).filter(\.$email == receivedData.email).all().count == 1 else {
            throw Abort(.notFound)
        }
        
        try await User.query(on: req.db)
            .filter(\.$email == receivedData.email)
            .set(\.$position, to: receivedData.position)
            .update()
        
        return Response(status: .accepted, version: .http3, headersNoUpdate: HTTPHeaders(), body: .empty)
    }
    
    /// Update user informations
    private func update(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(User.Update.self)
        guard userAuth.isActive else {
            throw Abort(.unauthorized)
        }
        
        var password = userAuth.password
        var token: UserToken?
        
        if let newPassword = try await checkNewPassword(for: userAuth, with: receivedData, in: req),
           let userID = userAuth.id {
            password = newPassword
            token = try await generateToken(for: userAuth, in: req)
            try await deleteToken(for: userID, in: req)
        }
        
        let addressId: UUID? = try await addressController.create(receivedData.address, for: req)
        
        try await User.query(on: req.db)
            .filter(\.$email == userAuth.email)
            .set(\.$firstname, to: receivedData.firstname)
            .set(\.$lastname, to: receivedData.lastname)
            .set(\.$phoneNumber, to: receivedData.phoneNumber)
            .set(\.$gender, to: receivedData.gender)
            .set(\.$password, to: password)
            .set(\.$missions, to: receivedData.missions)
            .set(\.$address.$id, to: addressId)
            .update()
        
        return Response(status: .accepted, version: .http3, headersNoUpdate: HTTPHeaders(), body: (token == nil) ? .empty : .init(data: try JSONEncoder().encode(token!.value)))
    }
    
    /// Getting the user list
    private func getList(req: Request) async throws -> Response {
        let users = try await User.query(on: req.db)
            .all()
            .map {
                return User.Informations(firstname: $0.firstname, lastname: $0.lastname, email: $0.email, phoneNumber: $0.phoneNumber, position: $0.position, gender: $0.gender, missions: $0.missions, address: $0.address)
            }
        
        return Response(status: .ok, version: .http3, headersNoUpdate: HTTPHeaders(), body: .init(data: try JSONEncoder().encode(users)))
    }
    
    // MARK: Utilities functions
    private func getUserAuthFor(_ req: Request) throws -> User {
        return try req.auth.require(User.self)
    }
    
    private func generateToken(for user: User, in req: Request) async throws -> UserToken {
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
    }
    
    private func deleteToken(for userID: UUID, in req: Request) async throws {
        try await UserToken.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
            .delete(on: req.db)
    }
    
    private func checkNewPassword(for user: User, with newInformations: User.Update, in req: Request) async throws -> String? {
        var newPassword: String?
        
        if let password = newInformations.password,
           let passwordVerification = newInformations.passwordVerification {
            guard password == passwordVerification else {
                throw Abort(.notAcceptable)
            }
            newPassword = try Bcrypt.hash(password)
        }
        
        return newPassword
    }
}
