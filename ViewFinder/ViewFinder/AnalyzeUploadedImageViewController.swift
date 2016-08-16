//
//  AnalyzeUploadedImageViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/22/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 * This ViewController calls APIs on an uploaded image that the user chooses
 * It checks for words to be translated, faces, and captions
 * the image.
*/

import Foundation
import UIKit

class AnalyzeUploadedImageViewController: UIView, UIPopoverPresentationControllerDelegate {
    
    var image = UIImage()
    var imageView = UIImageView()
    var captionLabel = UILabel()
    var closeButton = UIButton()
    var height = CGFloat()
    var width = CGFloat()
    var background = UILabel()
    
    var faces = [FaceDetectionBox]()
    var lines = [TranslateWordBox]()
    var translationDetails = [Dictionary<String, String>()]
    var detailButtons = [UIButton]()
    
    var celebrityPresent = false
    
    var camState = Int()
    var camDetails = String()
    
    var newHeight = CGFloat()
    var newWidth = CGFloat()
    
    init(height: CGFloat, width: CGFloat, image: UIImage) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        self.height = height
        self.width = width
        self.image = image
        
        setUpScreen()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //calls the APIs
    func setDetails(camState: Int, camDetails: String) {
        self.camState = camState
        self.camDetails = camDetails

        let header = ["Ocp-Apim-Subscription-Key": "8cace64f78f34355b7e2ab22e3b06bed", "Content-Type": "application/octet-stream"]
        
        let analyzeAPI = AnalyzeImageAPI(image: image, header: header)
        let ocrAPI = OCRAPI(image: image, header: header)

        if(camState == 0) {
            analyzeAPI.callAPI() { (rs: String) in
                if(!rs.containsString("Input image is too large")) {
                    print(rs)
                    self.displayAnswers(rs, image: self.image)
                } else {
                    print(rs)
                    self.captionLabel.backgroundColor = UIColor.redColor()
                    self.captionLabel.text = "Oops! Image too large!"
                }
            }
        } else if(camState == 1) {
            ocrAPI.callAPI() { (rs: String) in
                if(!rs.containsString("Input image is too large") && !rs.containsString("requestId")) {
                    self.translate(rs)
                } else {
                    self.captionLabel.backgroundColor = UIColor.redColor()
                    self.captionLabel.text = "Oops! Input image is too large"
                }
            }
        } else if(camState == 4) {
            let api = PrajnaAPI(image: image, classifier: camDetails)
            api.callAPI() { (rs: String) in
                if let dict = convertStringToDictionary(rs) {
                    if let description = dict["Description"] as? String {
                        if let name: String = (description.characters.split{$0 == ":"}.map(String.init))[0] {
                            self.captionLabel.text = name
                        }
                    }
                } else {
                    //catch for prajna service not working
                }
            }
        }
    }
    
 ////////////////////// POPOVERS //////////////////////////////
    
    //shows popovers of the translation details
    func showTranslationDetails(sender: AnyObject) {

        #if TENSORFLOW
            let storyboard = UIStoryboard(name: "Tensorflow", bundle: nil)
        #else
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
        #endif
        
        let controller = storyboard.instantiateViewControllerWithIdentifier("tdc") as! TranslationDetailViewController
        
        controller.preferredContentSize = CGSizeMake(300, 150)
        
        let details = translationDetails[sender.tag]
        
        controller.modalPresentationStyle = UIModalPresentationStyle.Popover
        
        let popoverPresentationController = controller.popoverPresentationController
        
        popoverPresentationController!.sourceView = self
        popoverPresentationController!.sourceRect = sender.frame
        
        popoverPresentationController!.permittedArrowDirections = .Any
        popoverPresentationController!.delegate = self
        
        controller.to = details["to"]!
        controller.from = details["from"]!
        controller.translated = details["translated"]!
        controller.original = details["original"]!
        
        let currentController = self.getCurrentViewController()
        currentController?.presentViewController(controller, animated: true, completion: nil)
    }
    
    //gets the current view controller
    func getCurrentViewController() -> UIViewController? {
        
        if let rootController = UIApplication.sharedApplication().keyWindow?.rootViewController {
            var currentController: UIViewController! = rootController
            while( currentController.presentedViewController != nil ) {
                currentController = currentController.presentedViewController
            }
            return currentController
        }
        return nil
        
    }
    
    func adaptivePresentationStyleForPresentationController(
        controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
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
        
        self.captionLabel.frame = CGRectMake(0.0, imageView.frame.maxY + 12, width, 44)
        
        if(camState == 0) {
            self.captionLabel.text = "Generating Caption..."
        } else if(camState == 1) {
            self.captionLabel.text = "Translating..."
        } else if(camState == 4) {
            self.captionLabel.text = "Finding " + getPrajnaNameFromCode(self.camDetails)
        }
        self.captionLabel.textAlignment = NSTextAlignment.Center
        self.captionLabel.backgroundColor = UIColor.blackColor()
        self.captionLabel.numberOfLines = 2
        self.captionLabel.textColor = UIColor.whiteColor()
        self.addSubview(self.captionLabel)
    }

 ////////////////////// PARSING JSON //////////////////////////
    
    /*
     *This calls an outside PHP script that handles translation and obtaining of access keys
     *@param: Dict: JSON returned from the OCR API
     */
    func translate(rs: String) {
        let dict = (convertStringToDictionary(rs)!)
        
        var numBoxes = 0
        
        var toTranslate = ""
        var originalText = [String]()
        //safely unwraps the json dictionary returned from the OCR API
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
                        self.addSubview(twb)
                        numBoxes += 1
                        originalText.append(str)
                        toTranslate = toTranslate + str + "*"
                    }
                }
                
            }
        }
        if(toTranslate != "") {
            let to = self.camDetails
            
            let encText = toTranslate.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            let fields = "?auth=96babypigmangocucumber&text=" + encText! + "&to=" + to
            
            let api = TranslateAPI(fields: fields)
            
            api.callAPI() { (rs: String) in
                
                let arr = rs.componentsSeparatedByString("&&#")
                let from = arr[0]
                let translated = arr[1].componentsSeparatedByString("$&$")
                for i in 0 ..< self.lines.count {
                    self.lines[i].outline.text = translated[i]
                    
                    let packet: Dictionary<String, String> = ["from": from, "original": originalText[i], "to": self.camDetails, "translated": translated[i]]
                    
                    //Adds Detail Button
                    let detailButton = UIButton()
                    let x = self.lines[i].outline.frame.minX
                    let y = self.lines[i].outline.frame.minY
                    let width = self.lines[i].outline.frame.width
                    let height = self.lines[i].outline.frame.height
                    if(height > 40) {
                        detailButton.frame = CGRect(x: x + width, y: y, width: 40.0, height: 40.0)
                    } else {
                        detailButton.frame = CGRect(x: x + width, y: y, width: height, height: height)
                    }
                    detailButton.setImage(UIImage(named: "detailButton.png"), forState: .Normal)
                    detailButton.tag = self.translationDetails.count
                    detailButton.userInteractionEnabled = true
                    
                    detailButton.addTarget(self, action: #selector(AnalyzeUploadedImageViewController.showTranslationDetails(_:)), forControlEvents: .TouchUpInside)
                    
                    let rootController = self.getCurrentViewController()
                    rootController!.view.addSubview(detailButton)
                    self.detailButtons.append(detailButton)
                    self.translationDetails.append(packet)
                    self.captionLabel.text = "Done Translating"
                }
            }
        } else {
            captionLabel.text = "Couldn't find any text in the picture"
        }
    }
    
    //parses the analyze image api json for faces, celebrities, and captions
    func displayAnswers(rs: String, image: UIImage) {
        let dict = (convertStringToDictionary(rs)!)
        
        if(rs.containsString("celeb")) {
            celebrityPresent = true
        }
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
                                                saveFaceFromImage(image, origin: CGPoint(x: y, y: x), name: celeb["name"] as! String)
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
    
    //resizes a frame for the given image
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
