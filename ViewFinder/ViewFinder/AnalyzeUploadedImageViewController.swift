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
    
    var celebrityPresent = false
    
    var newHeight = CGFloat()
    var newWidth = CGFloat()
    
    init(height: CGFloat, width: CGFloat, image: UIImage) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        self.height = height
        self.width = width
        self.image = image
        
        setUpScreen()
        
        analyzeImage(image)
    }
    
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
    
    //draws a rectangle over detected faces
    func drawFaceRectangle(x: Int, y: Int, height: Int, width: Int, caption: String) {
        
        var newX = Int(newWidth * (CGFloat(x) / self.image.size.width))
        var newY = Int(newHeight * (CGFloat(y) / self.image.size.height))
        
        if(newWidth == self.width) {
            newY = (Int(self.height - 88 - newHeight) / 2) + newY
        } else {
            newX = (Int(self.width - newWidth) / 2) + newX
        }
        
        let newSizeY = Int(newHeight * (CGFloat(height) / self.image.size.height))
        let newSizeX = Int(newWidth * (CGFloat(width) / self.image.size.width))
        
        let faceBox = FaceDetectionBox(x: newX, y: newY, height: newSizeY, width: newSizeX, caption: caption)
        self.addSubview(faceBox)
        faces.append(faceBox)
        print("Drew FaceBox at: " + String(newX) + ", " + String(newY) + " with dimensions " + String(newSizeX) + "x" + String(newSizeY))
        
    }
    
    //shows answers
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
                                        let width = faceR["width"] as! Int
                                        let height = faceR["height"] as! Int
                                        let rect = CGRect(x: x, y: y, width: width, height: height)
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
}