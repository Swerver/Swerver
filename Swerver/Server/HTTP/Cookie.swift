//
//  Cookie.swift
//  Swerver
//
//  Created by Julius Parishy on 12/17/15.
//  Copyright © 2015 Julius Parishy. All rights reserved.
//

import Foundation

struct Cookie {
    let name: String
    let value: String
    
    init?(string: String) {
        let scanner = NSScanner(string: string)
        
        var name: NSString? = nil
        if scanner.scanUpToString("=", intoString: &name), let name = name {
            let value = string.bridge().substringFromIndex(scanner.scanLocation + 1).swerver_stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            
            self.name = name.bridge()
            self.value = value
        } else {
            return nil
        }
    }
    
    static func parse(string: String) -> [Cookie] {
        let cookies: [Cookie?] = string.bridge().swerver_componentsSeparatedByString(";").map {
            str in
            let cleaned = str.bridge().swerver_stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            return Cookie(string: cleaned)
        }
        
        var out = [Cookie]()
        for c in cookies {
            if let c = c {
                out.append(c)
            }
        }
        
        return out
    }
}

extension Cookie : CustomStringConvertible {
    var description: String {
        return "<Cookie: name=\"\(name)\" value=\"\(value)\">"
    }
}
