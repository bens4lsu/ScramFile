import Fluent
import Vapor

func routes(_ app: Application, _ settings: ConfigurationSettings) throws {
    
    try app.register(collection: ContentController(settings))
    try app.register(collection: SecurityController(settings))
//    try app.register(collection: AdminController())

    
    
 /*
    app.get { req -> Response in
        if let _ = try SessionController.getUserId(req) {
            return req.redirect(to: "/top")
        }
        return req.redirect(to: "/security/login")
    }

*/
    
    app.get { req -> Response in
        SessionController.setUserId(req, UUID("DCBE4EAA-5CAF-11EB-A925-080027363641")!)
        SessionController.setIsAdmin(req, true)
        return req.redirect(to: "/top")
    }
}
