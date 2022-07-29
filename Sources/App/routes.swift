import Fluent
import Vapor

func routes(_ app: Application) throws {
    let addressController = AddressController()

    try app.register(collection: TripController(addressController: addressController))
    try app.register(collection: UserController(addressController: addressController))
    try app.register(collection: VolunteerController(addressController: addressController))
}
