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
    // MARK: Properties
    var addressController: AddressController
    
    // MARK: Route initialisation
    func boot(routes: RoutesBuilder) throws {
        let userGroup = routes.grouped("user")
        userGroup.post("create", use: create)
        
        let basicGroup = userGroup.grouped(User.authenticator()).grouped(User.guardMiddleware())
        basicGroup.post("login", use: login)
        
        let tokenGroup = userGroup.grouped(UserToken.authenticator()).grouped(UserToken.guardMiddleware())
        tokenGroup.patch("picture", use: updatePicture)
        tokenGroup.patch(use: update)
        tokenGroup.get(":image", ":extension", use: getProfilePicture)
    }
    
    // MARK: Routes functions
    /// Login function
    private func login(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(User.Login.self)
        
        try checkAccountActivation(of: userAuth)
        
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
    
    /// Update user informations
    private func update(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(User.Update.self)
        try checkAccountActivation(of: userAuth)
        
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
        
        let updatedUser = User.Informations(imagePath: userAuth.imagePath,
                                            id: userAuth.id ?? UUID(),
                                            firstname: receivedData.firstname,
                                            lastname: receivedData.lastname,
                                            email: userAuth.email,
                                            phoneNumber: receivedData.phoneNumber,
                                            gender: receivedData.gender,
                                            position: userAuth.position,
                                            missions: receivedData.missions,
                                            address: address,
                                            token: token.value,
                                            isActive: userAuth.isActive)
        
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
                .set(\.$imagePath, to: "\(userId)/\(fileExtension)")
                .update()
        }
        
        return .init(status: .accepted, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Get profile picture
    private func getProfilePicture(req: Request) async throws -> Response {
        let image = req.parameters.get("image", as: String.self)
        let imageExtension = req.parameters.get("extension", as: String.self)
        
        guard let image = image, let imageExtension = imageExtension else { throw Abort(.unauthorized) }
        
        let path = "\(image)"
        let downloadedImage = try await req.fileio.collectFile(at: "/var/www/html/AniTrip/Public/\(image).\(imageExtension)")
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(buffer: downloadedImage))
    }
    
    // MARK: Utilities functions
    /// Getting the connected user
    private func getUserAuthFor(_ req: Request) throws -> User {
        return try req.auth.require(User.self)
    }
    
    /// Generate token when login is success
    private func generateToken(for user: User, in req: Request) async throws -> UserToken {
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
    }
    
    /// Delete token for a selected user
    private func deleteToken(for userID: UUID, in req: Request) async throws {
        try await UserToken.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
            .delete(on: req.db)
    }
    
    /// Check if both new passwords are the same and not null
    private func checkNewPassword(for user: User, with newInformations: User.Update, in req: Request) async throws -> String? {
        guard (newInformations.password != nil && newInformations.passwordVerification != nil && newInformations.password != Optional("")) else { return nil }
        
        guard newInformations.password == newInformations.passwordVerification, let password = newInformations.password else {
            throw Abort(.notAcceptable)
        }
        
        return password
    }
    
    /// Getting the default HTTP headers
    private func getDefaultHttpHeader() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return headers
    }
    
    /// Check if the account is activate
    private func checkAccountActivation(of user: User) throws {
        guard user.isActive else {
            throw Abort(.custom(code: 460, reasonPhrase: "Account not active"))
        }
    }
}
