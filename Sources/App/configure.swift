import Vapor
import Fluent
import FluentMySQLDriver
import Leaf

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // register routes
        
    let settings = ConfigurationSettings()
    
    var tls = TLSConfiguration.makeClientConfiguration()
    tls.certificateVerification = settings.certificateVerification
    
    app.databases.use(.mysql(
        hostname: settings.database.hostname,
        username: settings.database.username,
        password: settings.database.password,
        database: settings.database.database,
        tlsConfiguration: tls
    ), as: .mysql)
    
    app.http.server.configuration.port = settings.listenOnPort
    
    // listen on local network
    //app.http.server.configuration.address = BindAddress.hostname("192.168.1.4", port: settings.listenOnPort)
    
    app.views.use(.leaf)
    
    try routes(app, settings)
    
    /// config max upload file size
    app.routes.defaultMaxBodySize = "80mb"
    
    /// setup public file middleware (for hosting our uploaded files)
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.middleware.use(app.sessions.middleware)

}
