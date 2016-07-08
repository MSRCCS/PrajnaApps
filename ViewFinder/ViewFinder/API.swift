//
//  API.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/5/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class API {
    
    var body: NSData
    var header: [String: String]
    var method: String
    var url: NSURL
    var translate: Bool
    
    let stateURLS: [Int: String] = [0: "https://api.projectoxford.ai/vision/v1.0/analyze", 1: "https://api.projectoxford.ai/vision/v1.0/ocr"]
    
    init(state: Int, header: [String: String], body: NSData, fields: String) {
        self.header = header
        self.body = body
        self.method = "POST"
        self.url = NSURL(string: stateURLS[state]! + fields)!
        self.translate = false
    }
    
    init(translate: Bool, fields: String) {
        self.translate = translate
        self.header = ["":""]
        self.body = NSData.init()
        self.method = "POST"
        self.url = NSURL(string: "https://metrofantasyball.com/translate/translatearray.php" + fields)!
    }
    
    func callAPI(completionHandler: (rs: String) -> ()) {
        var responseString = "" as NSString
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method
        
        if(!translate) {
            request.allHTTPHeaderFields = header
            request.HTTPBody = body
        }
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
            guard error == nil && data != nil else {            // check for fundamental networking error
                print("error=\(error)")
                return
            }
            
            if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode != 200 {  // check for http errors
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(response)")
            }
            
            responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)!
            //print("responseString = \(responseString)")
            
            dispatch_async(dispatch_get_main_queue()) {
                completionHandler(rs: responseString as String)
            }
            
        }
        task.resume()
    }
}