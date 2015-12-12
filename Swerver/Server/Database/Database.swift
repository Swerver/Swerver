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
            if let pgMessage = NSString(CString: PQerrorMessage(connection), encoding: NSUTF8StringEncoding)?.bridge() {
                message = pgMessage
            } else {
                message = "<No Error Message>"
            }
            
            throw DatabaseError.OpenFailure(status: Int(status.rawValue), message: message)
        }
    }
    
    func transaction(work: (Transaction) throws -> ()) throws {
        let transaction = Transaction(connection: connection)
        try transaction.begin()
        try work(transaction)
        try transaction.commit()
    }
}

enum DatabaseError : ErrorType {
    case OpenFailure(status: Int, message: String)
    case TransactionFailure(status: Int, message: String)
}

class Transaction {
    private let connection: COpaquePointer
    
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
                if let key = NSString(CString: PQfname(result, j), encoding: NSUTF8StringEncoding)?.bridge(),
                       value = NSString(CString: PQgetvalue(result, i, j), encoding: NSUTF8StringEncoding)?.bridge() {
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
            if let pgMessage = NSString(CString: PQresultErrorMessage(result), encoding: NSUTF8StringEncoding)?.bridge() {
                message = pgMessage
            } else {
                message = "<No Error Message>"
            }
            
            throw DatabaseError.TransactionFailure(status: Int(status.rawValue), message: message)
        }
        
        return result
    }
    
    private func begin() throws {
        try command("BEGIN")
    }
    
    private func commit() throws {
        try command("END")
    }
}
