import Fluent
import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: AddressController())
    try app.register(collection: TripController())
    try app.register(collection: UserController())
}
