//
//  ImageCaptureViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/20/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 * This is the ImageCaptureViewController. It enables a user to take
 * a picture and then call an API on it. It also has button to allow the user
 * to upload a picture
 
*/

import Foundation
import UIKit
import AVFoundation
import CoreImage
import MobileCoreServices



class ImageCaptureViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate, MenuViewControllerDelegate, UIPopoverPresentationControllerDelegate {
    
    var toggleButton = UIButton()
    var captureButton = UIButton()
    var uploadButton = UIButton()
    var switchButton = UIButton()
    var menuButton = UIButton()
    var saveButton = UIButton()
    let doubleTap = UITapGestureRecognizer()
    var swipe = UISwipeGestureRecognizer()
    var cover = UIView()
    var currentImage = UIImage()
    
    var boxView:UIView!;
    var previewView: UIView!;
    
    //Detection Helpers
    let captionLabel = UILabel()
    let dismissButton = UIButton()
    var faces = [FaceDetectionBox]()
    
    //Camera Capture requiered properties
    var videoDataOutput: AVCaptureVideoDataOutput!;
    var videoDataOutputQueue : dispatch_queue_t!;
    var previewLayer:AVCaptureVideoPreviewLayer!;
    var captureDevice : AVCaptureDevice!
    var frontDevice : AVCaptureDevice!
    var backDevice : AVCaptureDevice!
    let session=AVCaptureSession();
    let stillImageOutput = AVCaptureStillImageOutput()
    let imageView = UIImageView()
    let cameraPreview = UIView()
    
    var picker = UIImagePickerController()
    var analyzeUploadedImageView:AnalyzeUploadedImageViewController!
    var closeButton = UIButton()
    
    var currentFrame:CIImage!
    var done = false;
    var hasBack = false;
    var hasFront = false;
    var back = true;

    var celebrityPresent = false
    
    var wordBoxes = [TranslateWordBox]()
    var translationDetails = [Dictionary<String, String>()]
    var detailButtons = [UIButton]()
    
    //State Variables - Which API to call & details about it
    var camState = 0
    var camDetails = ":-)"
    let detailLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.previewView = UIView(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height));
        self.previewView.contentMode = UIViewContentMode.ScaleAspectFit
        self.view.addSubview(previewView);

        configureTapActions()
        
        self.picker.delegate = self
        
        self.setupAVCapture()
        
        self.tabBarController?.tabBar.hidden = true
    }
    
    override func viewWillAppear(animated: Bool) {
        if !done {
            session.startRunning();
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func shouldAutorotate() -> Bool {
        if (UIDevice.currentDevice().orientation == UIDeviceOrientation.LandscapeLeft ||
            UIDevice.currentDevice().orientation == UIDeviceOrientation.LandscapeRight ||
            UIDevice.currentDevice().orientation == UIDeviceOrientation.Unknown) {
            return false;
        }
        else {
            return true;
        }
    }
    
 /////////////////// CONFIGURE ACTIONS //////////////////
    
    
    //adds the double tap and swipe to the view
    func configureTapActions() {
        doubleTap.numberOfTapsRequired = 2
        doubleTap.addTarget(self, action: #selector(ImageCaptureViewController.toggle(_:)))
        
        swipe.addTarget(self, action: #selector(ImageCaptureViewController.viewFinder(_:)))
        swipe.delegate = self
        swipe.direction = .Right
        self.view.addGestureRecognizer(swipe)
    }
    
    func viewFinder(sender: UISwipeGestureRecognizer) {
        self.stopCamera()
        self.tabBarController?.selectedIndex = 0
        print("!!")
    }
    
    //adds attributes to the buttons and adds some of them to the view
    func addButtons() {
        //sets up the toggle button
        toggleButton.frame = CGRectMake(0, 20, 50, 40)
        toggleButton.addTarget(self, action: #selector(ImageCaptureViewController.toggle(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        let flipImage = UIImage(named:"FlipCameraButton.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        toggleButton.tintColor = UIColor.whiteColor()
        toggleButton.setImage(flipImage, forState: .Normal)
        //toggleButton.backgroundColor = UIColor.blackColor()
        self.view.addSubview(toggleButton)
        
        //sets up the capture button
        captureButton.frame = CGRectMake(self.view.frame.width / 2 - 45, self.view.frame.height - 110, 90, 90)
        let captureImage = UIImage(named: "CaptureButtonPNG.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        captureButton.tintColor = UIColor.whiteColor()
        captureButton.setImage(captureImage, forState: .Normal)
        captureButton.addTarget(self, action: #selector(ImageCaptureViewController.takePicture(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(captureButton)
        
        //sets up the dismiss button
        dismissButton.setTitle("Dismiss", forState: .Normal)
        dismissButton.backgroundColor = UIColor.whiteColor()
        dismissButton.setTitleColor(UIColor.blackColor(), forState: .Normal)
        dismissButton.addTarget(self, action: #selector(ImageCaptureViewController.dismissCapturedImage(_:)), forControlEvents: .TouchUpInside)
        
        //sets up the caption label
        captionLabel.backgroundColor = UIColor.blackColor()
        captionLabel.textColor = UIColor.whiteColor()
        captionLabel.textAlignment = NSTextAlignment.Center
        
        //sets up the close button
        closeButton.frame = CGRectMake(self.view.frame.size.width / 2 - 50, self.view.frame.size.height - 44, 100, 44)
        closeButton.layer.cornerRadius = 0.25 * closeButton.bounds.size.width
        closeButton.addTarget(self, action: #selector(ImageCaptureViewController.dismissUploadImageVC(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        closeButton.backgroundColor = UIColor.whiteColor()
        closeButton.setTitleColor(UIColor.blackColor(), forState: .Normal)
        closeButton.setTitle("Dismiss", forState: .Normal)
        
        //sets up the uploadButton
        uploadButton.frame = CGRect(x: self.view.frame.size.width - 60, y: self.view.frame.size.height - 60, width: 44, height: 44)
        let uploadImage = UIImage(named: "uploadButton.png")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        uploadButton.setImage(uploadImage, forState: .Normal)
        uploadButton.tintColor = UIColor.whiteColor()
        uploadButton.addTarget(self, action: #selector(ImageCaptureViewController.uploadPicture(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(uploadButton)
        
        //sets up the switch button
        switchButton.frame = CGRect(x: 16, y: self.view.frame.size.height - 54, width: 44, height: 33)
        let switchImage = UIImage(named: "glyphicons-facetime-video.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        switchButton.tintColor = UIColor.whiteColor()
        switchButton.setImage(switchImage, forState: .Normal)
        switchButton.addTarget(self, action: #selector(ImageCaptureViewController.viewFinder(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(switchButton)
        
        //sets up the Menu Button
        menuButton.frame = CGRect(x: self.view.frame.size.width - 45, y: 20, width: 40, height: 40)

        menuButton.setImage(UIImage(named: "MenuButton.png"), forState: .Normal)
        menuButton.addTarget(self, action: #selector(ImageCaptureViewController.showMenu(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(menuButton)
        
        detailLabel.frame = CGRect(x: self.view.frame.size.width - 150, y: 20, width: 100, height: 40)
        detailLabel.numberOfLines = 2
        detailLabel.textColor = UIColor.whiteColor()
        detailLabel.text = "Facial Recognition"
        detailLabel.textAlignment = .Right
        detailLabel.font = UIFont(name: (detailLabel.font?.fontName)!, size: 12.0)
        self.view.addSubview(detailLabel)
        
        cover.frame = CGRect(x: 0, y: self.view.frame.size.height - 44, width: self.view.frame.size.width, height: 44)
        cover.backgroundColor = UIColor.blackColor()
        
        self.saveButton.backgroundColor = UIColor.whiteColor()
        self.saveButton.setTitleColor(UIColor.blackColor(), forState: .Normal)
        self.saveButton.setTitle("Save", forState: .Normal)
    }
    
    //adds the translation detail view controller to the screen
    func showTranslationDetails(sender: UIButton) {
        
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
        
        popoverPresentationController!.sourceView = self.view
        popoverPresentationController!.sourceRect = sender.frame
        
        popoverPresentationController!.permittedArrowDirections = .Any
        popoverPresentationController!.delegate = self
        
        controller.to = details["to"]!
        controller.from = details["from"]!
        controller.translated = details["translated"]!
        controller.original = details["original"]!

        
        self.presentViewController(controller, animated: true, completion: nil)
    }

    
 /////////////////// PARSING JSON ///////////////////////

    //this is called after the analyze image api is used
    func displayAnswers(rs: String) {
        let dict = (convertStringToDictionary(rs)!)
        
        //parses analzyeimage api results
        if(self.camState == 0) {
            if let facesInImage = dict["faces"] as? [NSDictionary] {
                if(facesInImage.isEmpty) {
                    print("No Faces")
                } else {
                    print(String(facesInImage.count) + " faces detected")
                    
                    //loops through faces and gives each one a Face Rectangle
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
                                                let resizedHeight = self.view.frame.size.height * (self.view.frame.size.width / 480.0)
                                                let newX = Int(self.view.frame.size.width * (CGFloat(x) / 480.0))
                                                let newY = Int(resizedHeight * (CGFloat(y) / 640.0))
                                                
                                                //checks each FaceDetectionBox to see if is close to the celebrity face. If the origin point is within fifteen of the celebrity face the 'nametag' is replaced with the celebrity's name
                                                if(withinFifteen(Int(face.outline.frame.minX), two: newX) && withinFifteen(Int(face.outline.frame.minY), two: newY)) {
                                                    face.caption.text = (celeb["name"] as! String)
                                                    print(face.caption.text)
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
        
        //parses ocr json and calls translate api
        if(camState == 1) {
            
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
                            self.wordBoxes.append(twb)
                            self.view.addSubview(twb)
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
                
                let api = API(translate: true, fields: fields)
                
                api.callAPI() { (rs: String) in
                    
                    let arr = rs.componentsSeparatedByString("&&#")
                    let from = arr[0]
                    let translated = arr[1].componentsSeparatedByString("$&$")
                    for i in 0 ..< self.wordBoxes.count {
                        self.wordBoxes[i].outline.text = translated[i]
                        
                        let packet: Dictionary<String, String> = ["from": from, "original": originalText[i], "to": self.camDetails, "translated": translated[i]]
                        
                        //Adds Detail Button
                        let detailButton = UIButton()
                        let x = self.wordBoxes[i].outline.frame.minX
                        let y = self.wordBoxes[i].outline.frame.minY
                        let width = self.wordBoxes[i].outline.frame.width
                        detailButton.frame = CGRect(x: x + width, y: y, width: 24.0, height: 24.0)
                        detailButton.setImage(UIImage(named: "detailButton.png"), forState: .Normal)
                        detailButton.tag = self.translationDetails.count
                        detailButton.addTarget(self, action: #selector(ImageCaptureViewController.showTranslationDetails(_:)), forControlEvents: .TouchUpInside)
                        self.view.addSubview(detailButton)
                        self.detailButtons.append(detailButton)
                        self.translationDetails.append(packet)
                        self.captionLabel.text = "Done Translating"
                    }
                }
            } else {
                captionLabel.text = "Couldn't find any text in the picture"
            }
        }
    }
    
    
 /////////////////// CHANGE STATE //////////////////////
    
    //setter method for the language code
    func changeState(state: Int, details: String) {
        self.camDetails = details
        self.camState = state
        
        if(camState == 0) {
            detailLabel.text = "Facial Recognition"
        } else {
            detailLabel.text = "Translating Into " + getLanguageFromCode(camDetails)
        }
    }
    
    func adaptivePresentationStyleForPresentationController(
        controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
    //displays the language changing menu
    func showMenu(sender: AnyObject) {
        
        var storyboard = UIStoryboard()
        
        //checks to see if the target has a key set for tensorflow. Sets correct storyboard
        #if TENSORFLOW
            storyboard = UIStoryboard(name: "Tensorflow", bundle: nil)
        #else
            storyboard = UIStoryboard(name: "Main", bundle: nil)
        #endif
    
        let controller = storyboard.instantiateViewControllerWithIdentifier("menu") as! MenuViewController
        controller.preferredContentSize = CGSizeMake(180, 300)
        
        controller.modalPresentationStyle = UIModalPresentationStyle.Popover
        
        controller.delegate = self
        
        let popoverPresentationController = controller.popoverPresentationController
        
        popoverPresentationController!.sourceView = self.view
        popoverPresentationController!.sourceRect = menuButton.frame
        
        popoverPresentationController!.permittedArrowDirections = .Any
        popoverPresentationController!.delegate = self
        self.presentViewController(controller, animated: true, completion: nil)
        controller.setDetails(camState, camDetails: camDetails)
    }
    
 /////////////////// TAKE PICTURE ////////////////////
    
    /*
     * Takes picture and calls set API Method
     * @param: sender: AnyObject- method can be called by button or gesturerecognizer
     */
    func takePicture(sender: AnyObject) {
        let videoConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        if videoConnection != nil {
            
            // Secure image
            stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                
                let image = UIImage(data: imageData)
                // The above ^^ variable image is the captured image from the camera
                
                //UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil) // saves image
                
                
                var fields = ""
                
                if(self.camState == 0) {
                   // self.analyzeImage(image!) //calls analyze image API
                    self.captionLabel.text = "Generating Caption..."
                    
                    fields = "?visualFeatures=Faces,Description,Categories&details=Celebrities"

                } else if(self.camState == 1) {
                
                    self.captionLabel.text = "Getting Translation..."

                }
                
                let api = API(state: self.camState, header: ["Ocp-Apim-Subscription-Key": "8cace64f78f34355b7e2ab22e3b06bed", "Content-Type": "application/octet-stream"], body: UIImageJPEGRepresentation(image!, 0.9)!, fields: fields)
                
                api.callAPI() { (rs: String) in
                    if(rs.containsString("celebrities")) {
                        self.celebrityPresent = true
                    } else {
                        self.celebrityPresent = false
                    }
                    self.displayAnswers(rs)
                }
                
                let width = image!.size.width
                
                let resizedHeight = self.view.frame.size.height * (self.view.frame.size.width / width)
                
                self.imageView.image = image!
                self.imageView.frame = CGRect(x:0, y:0, width:self.view.frame.size.width, height: resizedHeight)
                self.view.addSubview(self.imageView)
                
                let dismissButtonHeight = ((self.view.frame.size.height - resizedHeight) / 2)
                
                
                self.cover.frame = CGRect(x: 0.0, y: self.view.frame.size.height - dismissButtonHeight, width: self.view.frame.size.width, height: dismissButtonHeight)
                self.view.addSubview(self.cover)
                
                self.captionLabel.frame = CGRect(x: 0, y: self.view.frame.size.height - (2 * dismissButtonHeight), width: self.view.frame.size.width, height: dismissButtonHeight + 4)
                self.view.addSubview(self.captionLabel)
                
                self.dismissButton.frame = CGRect(x: self.view.frame.size.width / 4 - 50,y: self.view.frame.size.height - dismissButtonHeight, width: 100, height: dismissButtonHeight)
                self.dismissButton.layer.cornerRadius = 0.25 * self.dismissButton.bounds.size.width
                self.view.addSubview(self.dismissButton)
                
                self.saveButton.frame = CGRect(x: 3 * (self.view.frame.size.width / 4) - 50,y: self.view.frame.size.height - dismissButtonHeight, width: 100, height: dismissButtonHeight)
                self.saveButton.layer.cornerRadius = 0.25 * self.saveButton.bounds.size.width
                self.saveButton.addTarget(self, action: #selector(self.save(_:)), forControlEvents: .TouchUpInside)
                self.view.addSubview(self.saveButton)
                
                self.currentImage = image!
            }
        }
    }
    
    func save(sender: UIButton) {
        UIImageWriteToSavedPhotosAlbum(currentImage, nil, nil, nil)
        saveButton.setTitle("✅", forState: .Normal)
        saveButton.backgroundColor = UIColor.darkGrayColor()
        saveButton.removeTarget(self, action: #selector(self.save(_:)), forControlEvents: .TouchUpInside)
    }
    
    //removes the image and detection views from the superview
    func dismissCapturedImage(sender: UIButton) {
        imageView.removeFromSuperview()
        dismissButton.removeFromSuperview()
        captionLabel.removeFromSuperview()
        cover.removeFromSuperview()
        saveButton.removeFromSuperview()
        saveButton.setTitle("Save", forState: .Normal)
        saveButton.backgroundColor = UIColor.whiteColor()
        
        //removes all the face detection boxes from the view
        if(!(faces.isEmpty)) {
            for face in faces {
                face.removeFromSuperview()
            }
            faces = [FaceDetectionBox]()
        }
        
        if(!(wordBoxes.isEmpty)) {
            for word in wordBoxes {
                word.removeFromSuperview()
            }
        }
        wordBoxes = [TranslateWordBox]()
        translationDetails = [Dictionary<String,String>()]
        if(!(detailButtons.isEmpty)) {
            for btn in detailButtons {
                btn.removeFromSuperview()
            }
        }
        
        detailButtons = [UIButton]()
    }
    
 /////////////////// UPLOADING ///////////////////////
    
    //adds the UIImagePickerController to the view
    func uploadPicture(sender: AnyObject) {
        
        self.picker.sourceType = UIImagePickerControllerSourceType.SavedPhotosAlbum
        
        self.presentViewController(self.picker, animated: true, completion: nil)
        
    }
    
    //called when image is selected to analyze
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            picker.dismissViewControllerAnimated(true, completion: nil)

            analyzeUploadedImageView = AnalyzeUploadedImageViewController(height: self.view.frame.size.height, width: self.view.frame.size.width, image: image)
            analyzeUploadedImageView.setDetails(camState, camDetails: camDetails)
            self.view.addSubview(analyzeUploadedImageView)
            
            self.view.addSubview(cover)
            self.view.addSubview(closeButton)
            
            swipe.removeTarget(self, action: #selector(ImageCaptureViewController.viewFinder(_:)))
            doubleTap.removeTarget(self, action: #selector(ImageCaptureViewController.toggle(_:)))
            session.stopRunning()
        }
    }
    
    //Called if user cancels picking an image - dismisses the UIImagePickerController
    func imagePickerControllerDidCancel(picker: UIImagePickerController)
    {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func dismissUploadImageVC(sender: AnyObject) {
        session.startRunning()
        analyzeUploadedImageView.removeFromSuperview()
        for btn in analyzeUploadedImageView.detailButtons {
            btn.removeFromSuperview()
        }
        analyzeUploadedImageView.detailButtons.removeAll()
        closeButton.removeFromSuperview()
        cover.removeFromSuperview()
        swipe.addTarget(self, action: #selector(ImageCaptureViewController.viewFinder(_:)))
        doubleTap.addTarget(self, action: #selector(ImageCaptureViewController.toggle(_:)))
    }
    
/////////////////// HELPER METHODS ///////////////////
    
    /*
     * Resizes a frame to fit the image instead of the view
     * @params: x,y: values of upper right corner of frame
     * @params: height,width: values of size of the rect
     * @return: returns the resized frame
     */
    func resizeFrame(x: Int, y: Int, height: Int, width: Int) -> CGRect {
        let resizedHeight = self.view.frame.size.height * (self.view.frame.size.width / 480.0)
        
        let newX = Int(self.view.frame.size.width * (CGFloat(x) / 480.0))
        let newY = Int(resizedHeight * (CGFloat(y) / 640.0))
        let newHeight = Int(resizedHeight * (CGFloat(height) / 640.0))
        let newWidth = Int(self.view.frame.size.width * (CGFloat(width) / 480.0))
        
        let frame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        return frame
    }
    
    //adjusts the size of a faceDetectorBox to fit the camera size
    //then calls the constructor to create a FaceDetection Box
    func drawFaceRectangle(x: Int, y: Int, height: Int, width: Int, caption: String) {
        
        //resizes and relocates the faceDetectorBox
        
        let frame = resizeFrame(x, y: y, height: height, width: width)
        
        //creates and Adds a FaceDetectionBox to the view
        let faceBox = FaceDetectionBox(frame: frame, caption: caption)
        self.view.addSubview(faceBox)
        faces.append(faceBox)
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
    
    
/////////////////// CAMERA METHODS //////////////////
    
    //toggles between the front and back cameras
    func toggle(sender: AnyObject) {
        
        for ii in session.inputs {
            session.removeInput(ii as! AVCaptureInput)
        }
        
        if(back) {
            if(hasFront) {
                var input = AVCaptureDeviceInput()
                do {
                    input = try AVCaptureDeviceInput(device: self.frontDevice)
                } catch {
                    
                }
                
                session.addInput(input)
                back = false
            }
        } else {
            if(hasBack) {
                var input = AVCaptureDeviceInput()
                do {
                    input = try AVCaptureDeviceInput(device: self.backDevice)
                } catch {
                    
                }
                
                session.addInput(input)
                back = true
            }
        }
    }
    
    //Touch to focus
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = touches.first!
        super.touchesBegan(touches, withEvent: event)
        
        let touchedPoint = touch.locationInView(cameraPreview)

        let newPoint = CGPoint(x: 480 * (touchedPoint.x / self.view.frame.size.width), y: 640 * (touchedPoint.y / self.view.frame.size.height))
        
        self.focusAtPoint(newPoint)
    }

}


//////////// CAMERA EXTENSION //////////////////////

// AVCaptureVideoDataOutputSampleBufferDelegate protocol and related methods
extension ImageCaptureViewController:  AVCaptureVideoDataOutputSampleBufferDelegate{
    func setupAVCapture(){
        session.sessionPreset = AVCaptureSessionPreset640x480;
        
        let devices = AVCaptureDevice.devices();
        // Get all devices
        for device in devices {
            // Check if device is media device
            if (device.hasMediaType(AVMediaTypeVideo)) {
                // Check for front/back camera
                if(device.position == AVCaptureDevicePosition.Back) {
                    backDevice = device as? AVCaptureDevice
                    captureDevice = device as? AVCaptureDevice;
                    hasBack = true
                } else if(device.position == AVCaptureDevicePosition.Front) {
                    frontDevice = device as? AVCaptureDevice
                    hasFront = true
                }
            }
        }
        if captureDevice != nil {
            beginSession();
            done = true;
        }
    }
    
    private func getImageFromBuffer(buffer: CMSampleBuffer) -> CIImage {
        let pixelBuffer = CMSampleBufferGetImageBuffer(buffer)
        
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, buffer, kCMAttachmentMode_ShouldPropagate)
        
        let image = CIImage(CVPixelBuffer: pixelBuffer!, options: attachments as? [String : AnyObject])
        
        return image
    }
    
    //starts up camera
    func beginSession(){
        var err : NSError? = nil
        var deviceInput:AVCaptureDeviceInput?
        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch let error as NSError {
            err = error
            deviceInput = nil
        };
        if err != nil {
            print("error: \(err?.localizedDescription)");
        }
        if self.session.canAddInput(deviceInput){
            self.session.addInput(deviceInput);
        }
        
        self.videoDataOutput = AVCaptureVideoDataOutput();
        self.videoDataOutput.alwaysDiscardsLateVideoFrames=true;
        self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        self.videoDataOutput.setSampleBufferDelegate(self, queue:self.videoDataOutputQueue);
        if session.canAddOutput(self.videoDataOutput){
            session.addOutput(self.videoDataOutput);
        }
        self.videoDataOutput.connectionWithMediaType(AVMediaTypeVideo).enabled = true;
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session);
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        
        if let previewLayer = AVCaptureVideoPreviewLayer(session: session) {
            previewLayer.bounds = view.bounds
            previewLayer.position = CGPointMake(view.bounds.midX, view.bounds.midY)
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            cameraPreview.frame = CGRectMake(0.0, 0.0, view.bounds.size.width, view.bounds.size.height)
            cameraPreview.layer.addSublayer(previewLayer)
            cameraPreview.addGestureRecognizer(doubleTap)
            view.addSubview(cameraPreview)
        }
        
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        if session.canAddOutput(stillImageOutput) {
            session.addOutput(stillImageOutput)
        }
        
        session.startRunning();
        addButtons()
    }
    
    // clean up AVCapture
    func stopCamera(){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.session.stopRunning()
            self.done = false;
        }
    }
    
    //focus camera at point
    func focusAtPoint(point: CGPoint) {
            let device: AVCaptureDevice = self.captureDevice
        do {
            try device.lockForConfiguration()
            if device.focusPointOfInterestSupported && device.isFocusModeSupported(AVCaptureFocusMode.AutoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = AVCaptureFocusMode.AutoFocus
            }
            
            device.unlockForConfiguration()
        } catch {
            //to do
        }
    }
    
    func convertImageFromCMSampleBufferRef(sampleBuffer:CMSampleBuffer) -> CIImage{
        let pixelBuffer:CVPixelBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer)!;
        let ciImage:CIImage = CIImage(CVPixelBuffer: pixelBuffer)
        return ciImage;
    }
}