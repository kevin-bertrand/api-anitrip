import APNS
import JWTKit
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    if app.environment == .production {
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database"
        ), as: .psql)
    } else {
        app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }

    // Cpnfigure APNS
    app.apns.configuration = try .init(authenticationMethod: .jwt(key: .private(filePath: Environment.get("FILE_PATH") ?? ""), keyIdentifier: JWKIdentifier(string: Environment.get("KEY_IDENTIFIER") ?? ""), teamIdentifier: Environment.get("TEAM_IDENTIFIER") ?? ""), topic: "com.desyntic.anitrip", environment: .sandbox)
    
    // Migration
    app.migrations.add(CreateAddress())
    app.migrations.add(CreateUser())
    app.migrations.add(CreateTrip())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateDevice())
    
    // register routes
    try routes(app)
}
