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
    
    var method: String!
    var url: NSURL!
    var body: NSData
    var header: [String:String]!
    
    init(method: String, url: NSURL, body: NSData, header: [String: String]) {
        self.method = method
        self.url = url
        self.body = body
        self.header = header
    }
    
    func callAPI(completionHandler: (rs: String) -> ()) {
        var responseString = "" as NSString
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method
        
        request.allHTTPHeaderFields = header
        request.HTTPBody = body
        
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

class PrajnaAPI: API {
    init(image: UIImage, classifier: String) {
        let url = NSURL(string: "http://vm-hub.trafficmanager.net/Vhub/Process/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/" + classifier + "/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/636064468986830000/0/SecretKeyShouldbeLongerThan10")
        super.init(method: "POST", url: url!, body: UIImageJPEGRepresentation(image, 0.9)!, header: [:])
    }
}

class AnalyzeImageAPI: API {
    init(image: UIImage, header: [String: String]) {
        super.init(method: "POST", url: NSURL(string: "https://api.projectoxford.ai/vision/v1.0/analyze?visualFeatures=Faces,Description,Categories&details=Celebrities")!, body: UIImageJPEGRepresentation(image, 0.9)!, header: header)
    }
}

class OCRAPI: API {
    init(image: UIImage, header: [String: String]) {
        super.init(method: "POST", url: NSURL(string: "https://api.projectoxford.ai/vision/v1.0/ocr")!, body: UIImageJPEGRepresentation(image, 0.9)!, header: header)
    }
}

class TranslateAPI: API {
    init(fields: String) {
        super.init(method: "POST", url: NSURL(string: "https://metrofantasyball.com/translate/translatearray.php" + fields)!, body: NSData.init(), header: [:])
    }
}

class KnowledgeAPI: API {
    init(name: String) {
        let nameArr = name.characters.split{$0 == " "}.map(String.init)
        var urlName = nameArr[0]
        for i in 1..<nameArr.count {
            urlName = urlName + "+" + nameArr[i]
        }
        
        let url = NSURL(string: "https://www.bingapis.com/api/v5/search?Knowledge=1&q=" + urlName + "&AppID=D41D8CD98F00B204E9800998ECF8427E496F9910&responseformat=json&responsesize=m")
        
        super.init(method: "POST", url: url!, body: NSData.init(), header: [:])
    }
}
