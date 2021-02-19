import Fluent
import Vapor

func routes(_ app: Application) throws {
    
    try app.register(collection: ContentController())
    try app.register(collection: SecurityController())
//    try app.register(collection: AdminController())

}
