import APNS
import JWTKit
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Mailgun
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    /// config max upload file size
    app.routes.defaultMaxBodySize = "10mb"
    
    // setup public file middleware (for hosting our uploaded files)
     app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

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
    
    // Port configuration
    app.http.server.configuration.hostname = "http://anitrip.desyntic.com"
    app.http.server.configuration.port = 2564
    
    // Configure MailGun
    app.mailgun.configuration = .environment
    app.mailgun.defaultDomain = .myApp
    
    let message = MailgunMessage(from: Environment.get("MAILGUN_FROM_EMAIL") ?? "", to: Environment.get("MAILGUN_ADMIN_EMAIL") ?? "", subject: "Server is started", text: "The server has started!")
    _ = try app.mailgun().send(message).wait()
    
    // Migration
    app.migrations.add(CreateAddress())
    app.migrations.add(CreateUser())
    app.migrations.add(CreateTrip())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateDevice())
    
    // register routes
    try routes(app)
}

extension MailgunDomain {
    static var myApp: MailgunDomain { .init(Environment.get("MAILGUN_DOMAIN") ?? "", .eu)}
}
