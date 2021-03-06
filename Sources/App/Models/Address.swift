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
    @Field(key: "road_name")
    var roadName: String
    
    @Field(key: "street_number")
    var streetNumber: String
    
    @OptionalField(key: "complement")
    var complement: String?
    
    @Field(key: "zip_code")
    var zipCode: String
    
    @Field(key: "city")
    var city: String
    
    @Field(key: "country")
    var country: String
    
    @Field(key: "latitude")
    var latitude: Double
    
    @Field(key: "longitude")
    var longitude: Double
    
    // Initialization functions
    init() {}
    
    init(id: UUID? = nil,
         streetNumber: String,
         roadName: String,
         complement: String?,
         zipCode: String,
         city: String,
         country: String,
         latitude: Double,
         longitude: Double) {
        self.id = id
        self.roadName = roadName
        self.streetNumber = streetNumber
        self.complement = complement
        self.zipCode = zipCode
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
}
