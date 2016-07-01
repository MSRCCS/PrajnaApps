//
//  AnalyzeUploadedImageViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/22/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class AnalyzeUploadedImageViewController: UIView {
    
    var image = UIImage()
    var imageView = UIImageView()
    var captionLabel = UILabel()
    var closeButton = UIButton()
    var height = CGFloat()
    var width = CGFloat()
    var background = UILabel()
    
    var faces = [FaceDetectionBox]()
    var lines = [TranslateWordBox]()
    
    var celebrityPresent = false
    
    var language = String()
    
    var newHeight = CGFloat()
    var newWidth = CGFloat()
    
    init(height: CGFloat, width: CGFloat, image: UIImage) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        self.height = height
        self.width = width
        self.image = image
        
        setUpScreen()
        
        analyzeImage(image)
        readWords(image)
    }
    

    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

 ////////////////////// CONFIGURE ACTIONS /////////////////////
    
    //adds caption label and fits the picture to the display
    func setUpScreen() {
        background.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height - 44)
        background.backgroundColor = UIColor.blackColor()
        self.addSubview(background)
        
        //sets the picture size
        if((image.size.width / width) > (image.size.height / height)) {
            //display landscape
            newHeight = image.size.height * (width / image.size.width)
            newWidth = image.size.width * (width / image.size.width)
            imageView.frame = CGRectMake(0.0, ((height - 88) - newHeight) / 2, newWidth, newHeight)
            
        } else {
            //display portrait
            newHeight = image.size.height * ((height - 88) / image.size.height)
            newWidth = image.size.width * ((height - 88) / image.size.height)
            imageView.frame = CGRectMake((width - newWidth) / 2, 0.0, newWidth, newHeight)
        }
        imageView.image = image
        self.addSubview(imageView)
        
        self.captionLabel.frame = CGRectMake(0.0, height - 88, width, 44)
        self.captionLabel.text = "Generating Caption..."
        self.captionLabel.textAlignment = NSTextAlignment.Center
        self.captionLabel.backgroundColor = UIColor.darkGrayColor()
        self.addSubview(self.captionLabel)
    }

 ////////////////////// PARSING JSON //////////////////////////
    
    /*
     *This calls an outside PHP script that handles translation and obtaining of access keys
     *@param: Dict: JSON returned from the OCR API
     */
    func translate(dict: NSDictionary) {
        
        var numBoxes = 0
        
        if let regions = dict["regions"] as? NSArray {
            for region in regions {
                if let lines = region["lines"] as? NSArray {
                    for line in lines {
                        let reg = line["boundingBox"] as! String
                        var str = ""
                        
                        if let words = line["words"] as? NSArray {
                            for word in words {
                                str = str + " " + (word["text"] as! String)
                            }
                        }
                        
                        let rect = getFrameFromStr(reg)
                        let twb = TranslateWordBox(frame: rect, caption: str)
                        self.lines.append(twb)
                        callTranslateAPI(str, boxId: numBoxes)
                        self.addSubview(twb)
                        numBoxes += 1
                    }
                }
                
            }
        }
    }
    
    //parses the analyze image api json for faces, celebrities, and captions
    func displayAnswers(rs: String) {
        let dict = (convertStringToDictionary(rs)!)
        
        if let facesInImage = dict["faces"] as? [NSDictionary] {
            if(facesInImage.isEmpty) {
                print("No Faces")
            } else {
                print(String(facesInImage.count) + " faces detected")
                
                for face in facesInImage {
                    let caption: String = String(face["age"] as! Int) + " y/o " + (face["gender"] as! String)
                    let x = face["faceRectangle"]!["left"] as! Int
                    let y = face["faceRectangle"]!["top"] as! Int
                    let width = face["faceRectangle"]!["width"] as! Int
                    let height = face["faceRectangle"]!["height"] as! Int
                    drawFaceRectangle(x, y: y, height: height, width: width, caption: caption)
                }
            }
            
            //safely unwraps the dictionary to check for celebrities
            if(celebrityPresent) {
                if let categories = dict["categories"] as? NSArray {
                    for i in 0 ..< categories.count {
                        if let details = categories[i]["detail"] as? NSDictionary {
                            if let celebrities = details["celebrities"] as? [NSDictionary] {
                                for celeb in celebrities {
                                    
                                    //loops through each celebrity
                                    
                                    if let faceR = celeb["faceRectangle"] as? NSDictionary {
                                        let x = faceR["left"] as! Int
                                        let y = faceR["top"] as! Int
                                        for face in faces {
                                            var newX = Int(newWidth * (CGFloat(x) / self.image.size.width))
                                            var newY = Int(newHeight * (CGFloat(y) / self.image.size.height))
                                            
                                            if(newWidth == self.width) {
                                                newY = (Int(self.height - 88 - newHeight) / 2) + newY
                                            } else {
                                                newX = (Int(self.width - newWidth) / 2) + newX
                                            }
                                            //checks each FaceDetectionBox to see if is close to the celebrity face. If the origin point is within fifteen of the celebrity face the 'nametag' is replaced with the celebrity's name
                                            if(withinFifteen(Int(face.outline.frame.minX), two: newX) && withinFifteen(Int(face.outline.frame.minY), two: newY)) {
                                                face.caption.text = (celeb["name"] as! String)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            print("Could not get Faces")
        }
        
        let x = (dict["description"] as! NSDictionary)["captions"]![0]["text"]
        
        captionLabel.text = (x as! String)
    }
    
 ////////////////////// API CALLS /////////////////////////////
    
    //calls the analyze image API
    func analyzeImage(image: UIImage) {
        var responseString = "" as NSString
        
        let request = NSMutableURLRequest(URL: NSURL(string: "https://api.projectoxford.ai/vision/v1.0/analyze?visualFeatures=Faces,Description,Categories&details=Celebrities")!)
        request.HTTPMethod = "POST"
        
        request.allHTTPHeaderFields = ["Ocp-Apim-Subscription-Key": "dca2b686d07a4e18ba81f5731053dbab", "Content-Type": "application/octet-stream"]
        request.HTTPBody = UIImageJPEGRepresentation(image, 0.9)
        
        
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
                if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode == 200 {
                    if((responseString as String).containsString("celebrities")) {
                        self.celebrityPresent = true
                    } else {
                        self.celebrityPresent = false
                    }
                    self.displayAnswers(responseString as String)
                } else {
                    self.captionLabel.backgroundColor = UIColor.redColor()
                    self.captionLabel.text = "Oops! Try again"
                }
            }
            
        }
        task.resume()
    }
    
    /*
     *This method calls the OCR API
     *@param: image: Image to call the OCR API on
     */
    func readWords(image: UIImage) {
        var responseString = "" as NSString
        
        let request = NSMutableURLRequest(URL: NSURL(string: "https://api.projectoxford.ai/vision/v1.0/ocr")!)
        request.HTTPMethod = "POST"
        
        request.allHTTPHeaderFields = ["Ocp-Apim-Subscription-Key": "dca2b686d07a4e18ba81f5731053dbab", "Content-Type": "application/octet-stream"]
        request.HTTPBody = UIImageJPEGRepresentation(image, 0.9)
        
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
                let dict = self.convertStringToDictionary(responseString as String)
                self.translate(dict!)
                
            }
            
        }
        task.resume()
    }
    
    /*
     * This method calls the translate API
     * @param: text: The text to be translated to
     * @param: boxId: The TranslateWordBox to add the translated text to
     */
    func callTranslateAPI(text: String, boxId: Int) {
        
        var responseString = "" as NSString
        
        let to = language
        
        let encText = text.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        
        let url = "https://metrofantasyball.com/translate/getaccesstoken.php?auth=96babypigmangocucumber&text=" + encText! + "&to=" + to
        
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        request.HTTPMethod = "POST"
        
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
            print("responseString = \(responseString)")
            
            dispatch_async(dispatch_get_main_queue()) {
                self.lines[boxId].outline.text = (responseString as String)
            }
            
        }
        task.resume()
    }
    
 ////////////////////// HELPER METHODS ////////////////////////
    
    /*
     * Turns a str of 4 digits separated by commas into a CGRect
     *@param: str: String to get frame from
     */
    func getFrameFromStr(str: String) -> CGRect{
        let strArr = str.characters.split{$0 == ","}.map(String.init)
        
        let x = Int(strArr[0])!
        let y = Int(strArr[1])!
        let width = Int(strArr[2])!
        let height = Int(strArr[3])!
        
        let rect = resizeFrame(x, y: y, height: height, width: width)
        
        return rect
    }

    //draws a rectangle over detected faces
    func drawFaceRectangle(x: Int, y: Int, height: Int, width: Int, caption: String) {
        let frame = resizeFrame(x, y: y, height: height, width: width)
        
        let faceBox = FaceDetectionBox(frame: frame, caption: caption)
        self.addSubview(faceBox)
        faces.append(faceBox)
    }
    
    func resizeFrame(x: Int, y: Int, height: Int, width: Int) -> CGRect {
        var newX = Int(newWidth * (CGFloat(x) / self.image.size.width))
        var newY = Int(newHeight * (CGFloat(y) / self.image.size.height))
        
        if(newWidth == self.width) {
            newY = (Int(self.height - 88 - newHeight) / 2) + newY
        } else {
            newX = (Int(self.width - newWidth) / 2) + newX
        }
        
        let newSizeY = Int(newHeight * (CGFloat(height) / self.image.size.height))
        let newSizeX = Int(newWidth * (CGFloat(width) / self.image.size.width))
        
        return CGRect(x: newX, y: newY, width: newSizeX, height: newSizeY)
    }
    
    //helper function - converts a json string into a dictionary
    func convertStringToDictionary(text: String) -> [String:AnyObject]? {
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
            do {
                return try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String:AnyObject]
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }
    
    //This checks to see if two numbers are within fifteen of each other
    //This is for updating the FaceDetectionBoxes with celebrity names
    func withinFifteen(one: Int, two: Int) -> Bool {
        if(two == one) {
            return true
        }
        if(two + 15 > one && two < one) {
            return true
        }
        if(one + 15 > two && one < two) {
            return true
        }
        return false
    }
    
}