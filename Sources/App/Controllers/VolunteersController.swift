//
//  VolunteersController.swift
//  
//
//  Created by Kevin Bertrand on 29/07/2022.
//

import Fluent
import Mailgun
import Vapor

struct VolunteerController: RouteCollection {
    // MARK: Properties
    var addressController: AddressController
    
    // MARK: Route initialisation
    func boot(routes: RoutesBuilder) throws {
        let volunteersGroup = routes.grouped("volunteers")
        let tokenGroup = volunteersGroup.grouped(UserToken.authenticator()).grouped(UserToken.guardMiddleware())
        tokenGroup.patch("activate", ":volunteerEmail", use: activate)
        tokenGroup.patch("desactivate", ":volunteerEmail", use: desactivate)
        tokenGroup.patch("delete", ":volunteerEmail", use: delete)
        tokenGroup.patch("position", use: updatePosition)
        tokenGroup.get(use: getList)
        tokenGroup.get("toActivate", use: getToActivateAccount)
    }
    
    // MARK: Routes functions
    /// Activate account of a volunteer
    private func activate(req: Request) async throws -> Response {
        guard try checkIfUserIsAdministrator(req) else {
            throw Abort(.unauthorized)
        }
        
        guard let userEmailToActivate = req.parameters.get("volunteerEmail"),
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
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Get account to active list
    private func getToActivateAccount(req: Request) async throws -> Response {
        guard try checkIfUserIsAdministrator(req) else {
            throw Abort(.unauthorized)
        }
        
        let userToActive = try await User.query(on: req.db)
            .filter(\.$isActive == false)
            .all()
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(userToActive)))
    }
    
    /// Delete account
    private func delete(req: Request) async throws -> Response {
        guard try checkIfUserIsAdministrator(req) else {
            throw Abort(.unauthorized)
        }
        
        guard let userEmailToDelete = req.parameters.get("volunteerEmail"),
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
        guard try checkIfUserIsAdministrator(req) else {
            throw Abort(.unauthorized)
        }
        
        guard let userEmailToDesactivate = req.parameters.get("volunteerEmail"),
              try await User.query(on: req.db).filter(\.$email == userEmailToDesactivate).all().count == 1 else {
            throw Abort(.notFound)
        }
        
        try await User.query(on: req.db)
            .filter(\.$email == userEmailToDesactivate)
            .set(\.$isActive, to: false)
            .update()
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Update position
    private func updatePosition(req: Request) async throws -> Response {
        guard try checkIfUserIsAdministrator(req) else {
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
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Getting volunteers list
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
    /// Getting the default HTTP headers
    private func getDefaultHttpHeader() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return headers
    }
    
    /// Check if the connected user is an administrator
    private func checkIfUserIsAdministrator(_ req: Request) throws -> Bool {
        return try req.auth.require(User.self).position == .administrator
    }
}
