//
//  UserController.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import APNS
import Fluent
import Vapor

struct UserController: RouteCollection {
    // Properties
    var addressController: AddressController
    
    
    func boot(routes: RoutesBuilder) throws {
        let userGroup = routes.grouped("user")
        userGroup.post("create", use: create)
        
        let basicGroup = userGroup.grouped(User.authenticator()).grouped(User.guardMiddleware())
        basicGroup.post("login", use: login)
        
        let tokenGroup = userGroup.grouped(UserToken.authenticator()).grouped(UserToken.guardMiddleware())
        tokenGroup.patch("activate", ":userEmail", use: activate)
        tokenGroup.patch("desactivate", ":userEmail", use: desactivate)
        tokenGroup.patch("delete", ":userEmail", use: delete)
        tokenGroup.patch("position", use: updatePosition)
        tokenGroup.patch(use: update)
        tokenGroup.get(use: getList)
        tokenGroup.get("toActivate", use: getToActivateAccount)
    }
    
    // MARK: Routes functions
    /// Login function
    private func login(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(User.Login.self)
        guard userAuth.isActive else {
            throw Abort(.custom(code: 460, reasonPhrase: "Account not active"))
        }
        let token = try await generateToken(for: userAuth, in: req)
        let userInformations = User.Informations(id: userAuth.id,
                                              firstname: userAuth.firstname,
                                              lastname: userAuth.lastname,
                                              email: userAuth.email,
                                              phoneNumber: userAuth.phoneNumber,
                                              gender: userAuth.gender,
                                              position: userAuth.position,
                                              missions: userAuth.missions,
                                              address: try await addressController.getAddressFromId(userAuth.$address.id, for: req),
                                              token: token.value,
                                              isActive: userAuth.isActive)
        
        let registerDeviceIdForUser = try await User.query(on: req.db)
            .filter(\.$email == userInformations.email)
            .first()
        
        var isAlreadyPresent = false
        
        if let devices = registerDeviceIdForUser?.devices {
            for device in devices {
                if device.deviceId == receivedData.deviceId {
                    isAlreadyPresent = true
                }
            }
        }
        
        if !isAlreadyPresent {
            let newDevice = Device(deviceId: receivedData.deviceId, userID: registerDeviceIdForUser?.id ?? UUID())
            try await newDevice.save(on: req.db)
        }
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(userInformations)))
    }
    
    /// Create new user
    private func create(req: Request) async throws -> Response {
        let receivedData = try req.content.decode(User.Create.self)
        guard receivedData.password == receivedData.passwordVerification else {
            throw Abort(.notAcceptable)
        }
        try await User(email: receivedData.email, password: try Bcrypt.hash(receivedData.password)).save(on: req.db)
        
        let alert = APNSwiftAlert(
            title: "New account request",
            body: "\(receivedData.email) want to create an account."
        )
        
        let administrators = try await User.query(on: req.db)
            .filter(\.$position == .administrator)
            .all()
        
        for administrator in administrators {
            for device in administrator.devices {
                _ = req.apns.send(alert, to: device.deviceId)
            }
        }
        
        return .init(status: .created, headers: getDefaultHttpHeader(), body: .empty)
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
        
        return .init(status: .accepted, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Get account to active list
    private func getToActivateAccount(req: Request) async throws -> Response {
        guard (try req.auth.require(User.self)).position == .administrator else {
            throw Abort(.unauthorized)
        }
        
        let userToActive = try await User.query(on: req.db)
            .filter(\.$isActive == false)
            .all()
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(userToActive)))
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
            .set(\.$isActive, to: false)
            .update()
        
        return .init(status: .accepted, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Desactivate account
    private func desactivate(req: Request) async throws -> Response {
        guard (try req.auth.require(User.self)).position == .administrator else {
            throw Abort(.unauthorized)
        }
        
        guard let userEmailToDesactivate = req.parameters.get("userEmail"),
              try await User.query(on: req.db).filter(\.$email == userEmailToDesactivate).all().count == 1 else {
            throw Abort(.notFound)
        }
        
        try await User.query(on: req.db)
            .filter(\.$email == userEmailToDesactivate)
            .set(\.$isActive, to: false)
            .update()
        
        return .init(status: .accepted, headers: getDefaultHttpHeader(), body: .empty)
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
        
        return .init(status: .accepted, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Update user informations
    private func update(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(User.Update.self)
        guard userAuth.isActive else {
            throw Abort(.custom(code: 460, reasonPhrase: "Account not active"))
        }
        
        guard let userID = userAuth.id else {
            throw Abort(.notAcceptable)
        }
        
        var password = userAuth.password

        if let newPassword = try await checkNewPassword(for: userAuth, with: receivedData, in: req) {
            password = try Bcrypt.hash(newPassword)
        }
        
        try await deleteToken(for: userID, in: req)
        let token = try await generateToken(for: userAuth, in: req)
        let address: Address? = try await addressController.create(receivedData.address, for: req)
        
        try await User.query(on: req.db)
            .filter(\.$email == userAuth.email)
            .set(\.$firstname, to: receivedData.firstname)
            .set(\.$lastname, to: receivedData.lastname)
            .set(\.$phoneNumber, to: receivedData.phoneNumber)
            .set(\.$gender, to: receivedData.gender)
            .set(\.$password, to: password)
            .set(\.$missions, to: receivedData.missions)
            .set(\.$address.$id, to: address?.id)
            .update()
        
        let updatedUser = User.Informations(id: userAuth.id, firstname: receivedData.firstname, lastname: receivedData.lastname, email: userAuth.email, phoneNumber: receivedData.phoneNumber, gender: receivedData.gender, position: userAuth.position, missions: receivedData.missions, address: address, token: token.value, isActive: userAuth.isActive)
        
        return .init(status: .accepted, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(updatedUser)))
    }
    
    /// Getting the user list
    private func getList(req: Request) async throws -> Response {
        let users = try await User.query(on: req.db)
            .all()

        var usersInformation: [User.Informations] = []
        
        for user in users {
            let address = try await addressController.getAddressFromId(user.$address.id, for: req)
            usersInformation.append(User.Informations(id: user.id, firstname: user.firstname, lastname: user.lastname, email: user.email, phoneNumber: user.phoneNumber, gender: user.gender, position: user.position, missions: user.missions, address: address, token: "", isActive: user.isActive))
        }

        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(usersInformation)))
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
        guard (newInformations.password != nil && newInformations.passwordVerification != nil && newInformations.password != Optional("")) else { return nil }
        
        guard newInformations.password == newInformations.passwordVerification, let password = newInformations.password else {
            throw Abort(.notAcceptable)
        }
        
        return password
    }
    
    private func getDefaultHttpHeader() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return headers
    }
}
