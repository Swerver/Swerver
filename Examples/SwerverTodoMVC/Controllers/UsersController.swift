//
//  UsersController.swift
//  Swerver
//
//  Created by Julius Parishy on 12/17/15.
//  Copyright © 2015 Julius Parishy. All rights reserved.
//

import Foundation

class UsersController : Controller {

    override func index(request: Request, parameters: Parameters, session: Session, transaction t: Transaction) throws -> ControllerResponse {
        return view(UserIndexView())
    }
    
    override func new(request: Request, parameters: Parameters, session inSession: Session, transaction t: Transaction) throws -> ControllerResponse {
        return view(UserNewView())
    }
    
    override func create(request: Request, parameters: Parameters, session: Session, transaction t: Transaction) throws -> ControllerResponse {
        if let email = parameters["email"] as? String, let password = parameters["password"] as? String {
            let mq = ModelQuery<User>(transaction: t)
            if try mq.findWhere(["email":email]).count != 0 {
                return view(UserNewView(), flash: ["error":"Email already exists"])
            } else {
            
                let user = User()
                
                user.email.update(email)
                user.updatePassword(password)
                
                let outUser = try mq.insert(user)
                
                var outSession = Session()
                outSession.update("user_id", outUser.id.value())
                
                return try redirect(to: "/", session: outSession)
            }
        } else {
            return view(UserNewView(), flash: ["error":"Missing Username or Password"])
        }
    }
    
    override func show(request: Request, parameters: Parameters, session: Session, transaction t: Transaction) throws -> ControllerResponse {
        if let param = parameters["id"] as? String, userID = Int(param) {
            return view(UserShowView(userID: userID))
        } else {
            return builtin(.NotFound)
        }
    }
}
