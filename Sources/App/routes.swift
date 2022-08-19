import Fluent
import Vapor
import Foundation

func routes(_ app: Application, _ settings: ConfigurationSettings) throws {
        
    try app.register(collection: ContentController(settings))
    
    let securityController = SecurityController(settings)
    try app.register(collection: securityController)
    
    try app.register(collection: AdminController(securityController))

    
    
 /*
    app.get { req -> Response in
        if let _ = try SessionController.getUserId(req) {
            return req.redirect(to: "/top")
        }
        return req.redirect(to: "/security/login")
    }

*/

    

//    app.get { req -> Response in
//        SessionController.setUserId(req, UUID("DCBE4EAA-5CAF-11EB-A925-080027363641")!)
//        SessionController.setIsAdmin(req, true)
//        return req.redirect(to: "/top")
//    }
    
    app.get { req -> Response in
        return req.redirect(to: "/security/login")
    }
    
    app.get("logout") { req -> Response in
        SessionController.kill(req)
        return req.redirect(to: "/security/login")
    }

}
