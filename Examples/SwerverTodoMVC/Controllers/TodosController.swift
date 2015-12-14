//
//  TodosController.swift
//  Swerver
//
//  Created by Julius Parishy on 12/11/15.
//  Copyright © 2015 Julius Parishy. All rights reserved.
//

import Foundation

class TodosController : Controller {
    override func index(request: Request, parameters: Parameters) throws -> Response {
        do {
            let db = try connect()
            return try db.transaction {
                t in
                
                let query = ModelQuery<Todo>(transaction: t)
                let results = try query.all()
                
                t.commit()
                
                do {
                    return try RespondTo(request) {
                        (format: ResponseFormat) throws -> Response in
                        switch format {
                        case .HTML:
                            return (.Ok, [:], nil)
                        case .JSON:
                            let dicts = try JSONDictionariesFromModels(results)
                            let data = try NSJSONSerialization.swerver_dataWithJSONObject(dicts, options: NSJSONWritingOptions(rawValue: 0))
                            return (.Ok, ["Content-Type":"application/json"], ResponseData.Data(data))
                        }
                    }
                } catch DatabaseError.TransactionFailure(_, let message) {
                    print(message)
                    return (.InternalServerError, [:], nil)
                }catch NSJSONSerialization.Error.InvalidInput {
                    print("invalid input")
                    return (.InternalServerError, [:], nil)
                    
                } catch {
                    return (.InternalServerError, [:], nil)
                }
            }
        } catch {
            return (.InternalServerError, [:], nil)
        }
    }
    
    override func create(request: Request, parameters: Parameters) throws -> Response {
        if let JSON = try parse(request) as? NSDictionary {
            do {
                let db = try connect()
                return try db.transaction {
                    t in
                    
                    let query = ModelQuery<Todo>(transaction: t)

                    let model: Todo = try ModelFromJSONDictionary(JSON)
                    try query.insert(model)
                    
                    t.commit()
                    
                    return (.Ok, [:], nil)
                }
            } catch {
                return (.InternalServerError, [:], nil)
            }
        } else {
            return (.InvalidRequest, [:], nil)
        }
    }
    
    override func update(request: Request, parameters: Parameters) throws -> Response {
        if let JSON = try parse(request) as? NSDictionary {
            do {
                let db = try connect()
                return try db.transaction {
                    t in
                    
                    let query = ModelQuery<Todo>(transaction: t)

                    let model: Todo = try ModelFromJSONDictionary(JSON)
                    try query.update(model)
                    
                    t.commit()
                    
                    return (.Ok, [:], nil)
                }
            } catch {
                return (.InternalServerError, [:], nil)
            }
        } else {
            return (.InvalidRequest, [:], nil)
        }
    }
}
