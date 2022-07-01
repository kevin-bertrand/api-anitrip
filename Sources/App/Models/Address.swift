//
//  Address.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

final class Address: Model, Content {
    // Name of the table
    static let schema: String = "address"
    
    // Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    // Fields
    @Field(key: "road_type")
    var roadType: String
    
    @Field(key: "road_name")
    var roadName: String
    
    @Field(key: "street_number")
    var streeNumber: String
    
    @OptionalField(key: "complement")
    var complement: String?
    
    @Field(key: "zip_code")
    var zipCode: String
    
    @Field(key: "city")
    var city: String
    
    @Field(key: "country")
    var country: String
    
    @Siblings(through: AddressTrip.self, from: \.$address, to: \.$trip)
    public var trips: [Trip]
    
    @Children(for: \.$address)
    var users: [User]
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil,
         roadType: String,
         streetNumber: String,
         complement: String?,
         zipCode: String,
         city: String,
         country: String) {
        self.id = id
        self.roadName = roadType
        self.streeNumber = streetNumber
        self.complement = complement
        self.zipCode = zipCode
        self.city = city
        self.country = country
    }
}
