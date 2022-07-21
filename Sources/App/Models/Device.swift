//
//  Device.swift
//  
//
//  Created by Kevin Bertrand on 21/07/2022.
//

import Fluent
import Vapor

final class Device: Model, Content {
    // Name of the table
    static let schema: String = "device"
    
    // Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    // Fields
    @Field(key: "device_id")
    var deviceId: String
    
    @Parent(key: "user_id")
    var user: User
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil, deviceId: String, userID: User.IDValue) {
        self.id = id
        self.deviceId = deviceId
        self.$user.id = userID
    }
}
