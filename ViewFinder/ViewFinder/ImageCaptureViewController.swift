//
//  ImageCaptureViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/20/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

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
    let doubleTap = UITapGestureRecognizer()
    var swipe = UISwipeGestureRecognizer()
    
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
    
    var language = "en"
    
    var celebrityPresent = false
    
    var wordBoxes = [TranslateWordBox]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.previewView = UIView(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height));
        self.previewView.contentMode = UIViewContentMode.ScaleAspectFit
        self.view.addSubview(previewView);

        configureTapActions()
        
        self.picker.delegate = self
        
        self.setupAVCapture()
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
    
    
    //adds the double tap to the view
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
        performSegueWithIdentifier("viewFinder", sender: nil)
    }
    
    //adds attributes to the buttons and adds some of them to the view
    func addButtons() {
        //sets up the toggle button
        toggleButton.frame = CGRectMake(0, 20, 45, 25)
        toggleButton.addTarget(self, action: #selector(ImageCaptureViewController.toggle(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        let flipImage = UIImage(named:"FlipCameraButton.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        toggleButton.tintColor = UIColor.whiteColor()
        toggleButton.setImage(flipImage, forState: .Normal)
        //toggleButton.backgroundColor = UIColor.blackColor()
        self.view.addSubview(toggleButton)
        
        //sets up the capture button
        captureButton.frame = CGRectMake(self.view.frame.width / 2 - 45, self.view.frame.height - 110, 90, 90)
        let captureImage = UIImage(named: "CaptureButtonPNG.png")!
        captureButton.setImage(captureImage, forState: .Normal)
        captureButton.addTarget(self, action: #selector(ImageCaptureViewController.takePicture(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(captureButton)
        
        //sets up the dismiss button
        dismissButton.setTitle("Dismiss", forState: .Normal)
        dismissButton.backgroundColor = UIColor.blackColor()
        dismissButton.addTarget(self, action: #selector(ImageCaptureViewController.dismissCapturedImage(_:)), forControlEvents: .TouchUpInside)
        
        //sets up the caption label
        captionLabel.backgroundColor = UIColor.darkGrayColor()
        captionLabel.textColor = UIColor.whiteColor()
        captionLabel.textAlignment = NSTextAlignment.Center
        
        //sets up the close button
        closeButton.frame = CGRectMake(0.0, self.view.frame.size.height - 44, self.view.frame.size.width, 44)
        closeButton.addTarget(self, action: #selector(ImageCaptureViewController.dismissUploadImageVC(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        closeButton.backgroundColor = UIColor.blackColor()
        closeButton.setTitle("Dismiss", forState: .Normal)
        
        //sets up the uploadButton
        uploadButton.frame = CGRect(x: self.view.frame.size.width - 60, y: self.view.frame.size.height - 60, width: 44, height: 44)
        let uploadImage = UIImage(named: "uploadButton.png")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        uploadButton.setImage(uploadImage, forState: .Normal)
        uploadButton.tintColor = UIColor.darkGrayColor()
        uploadButton.addTarget(self, action: #selector(ImageCaptureViewController.uploadPicture(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(uploadButton)
        
        //sets up the switch button
        switchButton.frame = CGRect(x: 0, y: self.view.frame.size.height - 60, width: 80, height: 60)
        switchButton.setTitle("LIVE", forState: .Normal)
        switchButton.addTarget(self, action: #selector(ImageCaptureViewController.viewFinder(_:)), forControlEvents: .TouchUpInside)
        //switchButton.backgroundColor = UIColor.whiteColor()
        switchButton.setTitleColor(UIColor.grayColor(), forState: .Normal)
        self.view.addSubview(switchButton)
        
        //sets up the Menu Button
        menuButton.frame = CGRect(x: self.view.frame.size.width - 60, y: 20, width: 44, height: 44)
        //let menuImage = UIImage(named: "menuButtonSlim2.png")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        //menuButton.setImage(menuImage, forState: .Normal)
        let index: String.Index = language.startIndex.advancedBy(2) // Swift 2
        var ss2:String = language.substringToIndex(index) // "Stack"
        ss2 = ss2.uppercaseString
        menuButton.setTitle(ss2, forState: .Normal)
        menuButton.titleLabel?.textColor = UIColor.blackColor()
        menuButton.titleLabel?.adjustsFontSizeToFitWidth = true
        menuButton.tintColor = UIColor.blackColor()
        menuButton.addTarget(self, action: #selector(ImageCaptureViewController.showMenu(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(menuButton)
    }

    
 /////////////////// PARSING JSON ///////////////////////
    
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
                        self.wordBoxes.append(twb)
                        callTranslateAPI(str, boxId: numBoxes)
                        self.view.addSubview(twb)
                        numBoxes += 1
                    }
                }
                
            }
        }
    }
    
    
    
    
    
    //this is called after the analyze image api is used
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
                                            let resizedHeight = self.view.frame.size.height * (self.view.frame.size.width / 480.0)
                                            let newX = Int(self.view.frame.size.width * (CGFloat(x) / 480.0))
                                            let newY = Int(resizedHeight * (CGFloat(y) / 640.0))
                                            
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
    
    
 /////////////////// CHANGE LANGUAGE ////////////////////
    
    //setter method for the language code
    func changeLanguage(language: String) {
        self.language = language
        
        let index: String.Index = language.startIndex.advancedBy(2) // Swift 2
        var ss2:String = language.substringToIndex(index) // "Stack"
        ss2 = ss2.uppercaseString
        menuButton.setTitle(ss2, forState: .Normal)
    }
    
    func adaptivePresentationStyleForPresentationController(
        controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
    //displays the language changing menu
    func showMenu(sender: AnyObject) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("menu") as! MenuViewController
        
        controller.current = self.language
        controller.preferredContentSize = CGSizeMake(250, 300)
        
        controller.modalPresentationStyle = UIModalPresentationStyle.Popover
        
        controller.delegate = self
        
        let popoverPresentationController = controller.popoverPresentationController
        
        popoverPresentationController!.sourceView = self.view
        popoverPresentationController!.sourceRect = menuButton.frame
        
        popoverPresentationController!.permittedArrowDirections = .Any
        popoverPresentationController!.delegate = self
        
        self.presentViewController(controller, animated: true, completion: nil)
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
                
                
                self.analyzeImage(image!) //calls analyze image API
                
                self.readWords(image!) //calls the OCR API
                
                let width = image!.size.width
                
                let resizedHeight = self.view.frame.size.height * (self.view.frame.size.width / width)
                
                self.imageView.image = image!
                self.imageView.frame = CGRect(x:0, y:0, width:self.view.frame.size.width, height: resizedHeight)
                self.view.addSubview(self.imageView)
                
                let dismissButtonHeight = ((self.view.frame.size.height - resizedHeight) / 2)
                
                self.dismissButton.frame = CGRect(x: 0,y: self.view.frame.size.height - dismissButtonHeight, width: self.view.frame.size.width, height: dismissButtonHeight)
                self.view.addSubview(self.dismissButton)
                self.captionLabel.text = "Generating Caption..."
                self.captionLabel.frame = CGRect(x: 0, y: self.view.frame.size.height - (2 * dismissButtonHeight), width: self.view.frame.size.width, height: dismissButtonHeight + 4)
                self.view.addSubview(self.captionLabel)
            }
        }
    }
    
    //removes the image and detection views from the superview
    func dismissCapturedImage(sender: UIButton) {
        imageView.removeFromSuperview()
        dismissButton.removeFromSuperview()
        captionLabel.removeFromSuperview()
        
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
            
            self.view.addSubview(analyzeUploadedImageView)
            self.view.addSubview(closeButton)
            swipe.removeTarget(self, action: #selector(ImageCaptureViewController.viewFinder(_:)))
        }
    }
    
    //Called if user cancels picking an image - dismisses the UIImagePickerController
    func imagePickerControllerDidCancel(picker: UIImagePickerController)
    {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func dismissUploadImageVC(sender: AnyObject) {
        analyzeUploadedImageView.removeFromSuperview()
        closeButton.removeFromSuperview()
        swipe.addTarget(self, action: #selector(ImageCaptureViewController.viewFinder(_:)))
    }
    
    
 /////////////////// API CALLS ///////////////////////
    
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
                self.wordBoxes[boxId].outline.text = (responseString as String)
            }
            
        }
        task.resume()
    }
    
    /*
     * Calls the Analyze Image API
     * @param: image: image sent to Analyze Image API
     */
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
                
                if((responseString as String).containsString("celebrities")) {
                    self.celebrityPresent = true
                } else {
                    self.celebrityPresent = false
                }
                
                self.displayAnswers(responseString as String)
                
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