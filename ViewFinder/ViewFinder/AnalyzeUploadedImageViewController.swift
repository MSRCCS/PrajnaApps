//
//  AnalyzeUploadedImageViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/22/16.
//  Copyright © 2016 Jacob Kohn. All rights reserved.
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
    
    var newHeight = CGFloat()
    var newWidth = CGFloat()
    
    init(height: CGFloat, width: CGFloat, image: UIImage) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        print("!")
        
        self.height = height
        self.width = width
        self.image = image
        
        setUpScreen()
        
        analyzeImage(image)
    }
    
    func setUpScreen() {
        background.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height - 44)
        background.backgroundColor = UIColor.blackColor()
        self.addSubview(background)
        

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
        self.captionLabel.text = "Generating Caption"
        self.captionLabel.textAlignment = NSTextAlignment.Center
        self.captionLabel.backgroundColor = UIColor.darkGrayColor()
        self.addSubview(self.captionLabel)
    }
    
    func dismiss(sender: AnyObject) {
        print("!!")
        captionLabel.removeFromSuperview()
        closeButton.removeFromSuperview()
        background.removeFromSuperview()
        imageView.removeFromSuperview()
        self.removeFromSuperview()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func analyzeImage(image: UIImage) {
        var responseString = "" as NSString
        
        let request = NSMutableURLRequest(URL: NSURL(string: "https://api.projectoxford.ai/vision/v1.0/analyze?visualFeatures=Faces,Description,Categories&details=Celebrities")!)
        request.HTTPMethod = "POST"
        

        request.allHTTPHeaderFields = ["Ocp-Apim-Subscription-Key": "dca2b686d07a4e18ba81f5731053dbab", "Content-Type": "application/octet-stream"]
        request.HTTPBody = UIImagePNGRepresentation(image)

        
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
                    self.displayAnswers(responseString as! String)
                } else {
                    self.captionLabel.backgroundColor = UIColor.redColor()
                    self.captionLabel.text = "Oops! Try again"
                }
            }
            
        }
        task.resume()
    }
    
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
            
            if let cats = dict["categories"] as? [NSDictionary] {
                for cat in cats {
                    if let title = cat["name"] as? String  {
                        if(title == "people_") {
                            if let celebs = cat["detail"]!["celebrities"] as? [NSDictionary] {
                                for face in celebs {
                                    let caption: String = face["name"] as! String
                                    let x = face["faceRectangle"]!["left"] as! Int
                                    let y = face["faceRectangle"]!["top"] as! Int
                                    let width = face["faceRectangle"]!["width"] as! Int
                                    let height = face["faceRectangle"]!["height"] as! Int
                                    drawFaceRectangle(x, y: y, height: height, width: width, caption: caption)
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