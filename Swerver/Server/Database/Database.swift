//
//  Database.swift
//  Swerver
//
//  Created by Julius Parishy on 12/11/15.
//  Copyright © 2015 Julius Parishy. All rights reserved.
//

import Foundation

class Database {
    let connection: COpaquePointer
    
    deinit {
        PQfinish(connection)
    }
    
    init(databaseName: String, username: String, password: String = "") throws {
        connection = PQsetdbLogin(nil, nil, nil, nil, databaseName, username, password)
        let status = PQstatus(connection)
        if status != CONNECTION_OK {
        
            let message: String
            if let pgMessage = NSString.fromCString(PQerrorMessage(connection))?.bridge() {
                message = pgMessage
            } else {
                message = "<No Error Message>"
            }
            
            throw DatabaseError.OpenFailure(status: Int(status.rawValue), message: message)
        }
    }
    
    func transaction<T>(work: (Transaction) throws -> (T)) throws -> T {
        let transaction = Transaction(connection: connection)
        try transaction.begin()
        let ret = try work(transaction)
        if transaction._closed != true {
            throw DatabaseError.TransactionNotClosed
        }
        
        return ret
    }
}

enum DatabaseError : ErrorType {
    case OpenFailure(status: Int, message: String)
    case TransactionFailure(status: Int, message: String)
    case TransactionNotClosed
}

public class Transaction {
    private let connection: COpaquePointer
    
    private var _closed = false
    private var _models: [Model] = []
    
    private init(connection: COpaquePointer) {
        self.connection = connection
    }
    
    typealias QueryResult = [[String:String]]
    
    internal func command(command: String) throws {
        try exec(command, expectedStatus: PGRES_COMMAND_OK)
    }
    
    internal func query(command: String) throws -> QueryResult {
        let result = try exec(command, expectedStatus: PGRES_TUPLES_OK)
        
        let numberOfFields = PQnfields(result)
        var results = [[String:String]]()
        
        let numberOfResults = PQntuples(result)
        for i in 0..<numberOfResults {
            
            var row = [String:String]()
            for j in 0..<numberOfFields {
                if let key = NSString.fromCString(PQfname(result, j))?.bridge(),
                     value = NSString.fromCString(PQgetvalue(result, i, j))?.bridge() {
                    row[key] = value
                }
            }
            
            results.append(row)
        }
        
        return results
    }
    
    private func exec(command: String, expectedStatus: ExecStatusType) throws -> COpaquePointer {
        let result = PQexec(connection, command)
        
        let status = PQresultStatus(result)
        if status != expectedStatus {
        
            let message: String
            if let pgMessage = NSString.fromCString(PQresultErrorMessage(result))?.bridge() {
                message = pgMessage
            } else {
                message = "<No Error Message>"
            }
            
            throw DatabaseError.TransactionFailure(status: Int(status.rawValue), message: message)
        }
        
        return result
    }
    
    internal func register(model: Model) {
        _models.append(model)
    }
    
    private func commitDirtyModels() throws {
        for m in _models {
            let primaryKey = m.dynamicType.primaryKey
            if let primaryKeyValue = try m.map[primaryKey]?.databaseValueForWriting() {
                var query = "UPDATE \(m.dynamicType.table) SET "
                
                var index = 0
                var dirtyProps = 0
                for (k,v) in m.map {
                    if v.dirty == false || k == primaryKey {
                        index++
                        continue
                    }
                    
                    let vs = try v.databaseValueForWriting()
                    query += "\(k) = \(vs)"
                    
                    if index < (m.map.count - 1) {
                        query += ", "
                    } else {
                        query += " "
                    }
                    
                    dirtyProps++
                    index++
                }
                
                if dirtyProps == 0 {
                    break
                }
                
                query += "WHERE \(m.dynamicType.primaryKey) = \(primaryKeyValue);"
                try self.command(query)
            } else {
                print("WARNING: \(m) is dirty but does not have a valid primary key and cannot be updated.")
            }
        }
    }
    
    private func begin() throws {
        try command("BEGIN")
    }
    
    public func commit() {
        do {
            try commitDirtyModels()
            try command("END")
        } catch {}
        
        _closed = true
    }
}
