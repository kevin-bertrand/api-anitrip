//
//  UserController.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import APNS
import Fluent
import Mailgun
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
        tokenGroup.patch("picture", use: updatePicture)
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
        let userInformations = User.Informations(imagePath: userAuth.imagePath,
                                                 id: userAuth.id ?? UUID(),
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
        
        let userDevices = try await Device.query(on: req.db)
            .filter(\.$user.$id == userInformations.id)
            .filter(\.$deviceId == receivedData.deviceId)
            .all()
        
        if userDevices.count == 0 {
            let newDevice = Device(deviceId: receivedData.deviceId, userID: userInformations.id)
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
            subtitle: "\(receivedData.email)",
            body: "\(receivedData.email) want to create an account."
        )
        
        let devicesArray = try await User.query(on: req.db)
            .filter(\.$position == .administrator)
            .all()
            .map({ users in
                try users.$devices.get(on: req.db)
                    .wait()
            })

        for devices in devicesArray {
            for device in devices {
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
    
        let message = MailgunMessage(from: Environment.get("MAILGUN_FROM_EMAIL") ?? "",
                                     to: userEmailToActivate,
                                     subject: "Account activation",
                                     text: """
                                     Dear \(userEmailToActivate),
                                     
                                     Your account is now activate!
                                     Go to the application to connect with your email and your password.
                                     
                                     Don't forget to fill your profile with your personnal informations!
                                     
                                     Regards.
                                     
                                     -----------------------------------------------
                                     This is an automatic email, do not reply!
                                     """)
        
        _ = req.mailgun().send(message).map { _ in
            return true
        }
        
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
        
        let updatedUser = User.Informations(imagePath: userAuth.imagePath, id: userAuth.id ?? UUID(), firstname: receivedData.firstname, lastname: receivedData.lastname, email: userAuth.email, phoneNumber: receivedData.phoneNumber, gender: receivedData.gender, position: userAuth.position, missions: receivedData.missions, address: address, token: token.value, isActive: userAuth.isActive)
        
        return .init(status: .accepted, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(updatedUser)))
    }
    
    /// Update user profile picture
    private func updatePicture(req: Request) async throws -> Response {
        let file = try req.content.decode(File.self)
        guard let fileExtension = file.extension else { throw Abort(.badRequest)}
        
        let userAuth = try getUserAuthFor(req)
        
        if let userId = userAuth.id {
            let path =  "/var/www/html/AniTrip/Public/\(userId)." + fileExtension
            try await req.fileio.writeFile(file.data, at: path)
            
            
            try await User.query(on: req.db)
                .filter(\.$email == userAuth.email)
                .set(\.$imagePath, to: path)
                .update()
        }
        
        return .init(status: .accepted, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Getting the user list
    private func getList(req: Request) async throws -> Response {
        let users = try await User.query(on: req.db)
            .all()

        var usersInformation: [User.Informations] = []
        
        for user in users {
            let address = try await addressController.getAddressFromId(user.$address.id, for: req)
            usersInformation.append(User.Informations(imagePath: user.imagePath, id: user.id ?? UUID(), firstname: user.firstname, lastname: user.lastname, email: user.email, phoneNumber: user.phoneNumber, gender: user.gender, position: user.position, missions: user.missions, address: address, token: "", isActive: user.isActive))
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
