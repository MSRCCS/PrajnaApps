//
//  SteadyViewFinderViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/30/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 * This is the current ViewFinder ViewController
 * In this ViewFinder, the user must steady the camera 
 * for a given period of time for it to be able to
 * recognize what it sees in the image.
 
 
*/

import Foundation
import UIKit
import CoreImage
import CoreMotion
import AVFoundation


class SteadyViewFinderViewController: UIViewController, UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate, MenuViewControllerDelegate {
    
    var trackingImage = UIImage()
    
    var toggleButton = UIButton()
    var switchButton = UIButton()
    
    let doubleTap = UITapGestureRecognizer()
    let swipe = UIPanGestureRecognizer()
    
    var boxView:UIView!;
    var previewView: UIView!;
    
    //Detection Helpers
    let captionLabel = UILabel()
    let dismissButton = UIButton()
    var textBoxes = [TranslateWordBox]()
    var faces = [SteadyViewFinderViewController.face()]
    //var faceFeatures
    var totalFacesDetected = 1          // starts at one so doesn't get initializer. Sets IDs for the faces
    
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
    
    var currentFrame:CIImage!
    var done = false;
    var hasBack = false;
    var hasFront = false;
    var back = true;
    
    //Face Detector
    var detector: CIDetector?
    var options: [String : AnyObject]?
    var context: CIContext?
    var hasFace = false
    var callFaceAPI = false
    var celebrityPresent = false
    
    //Text Detector
    var textDetector: CIDetector?
    var textDetectorOptions: [String : AnyObject]?
    var textContext: CIContext?
    var hasText = false
    var callOcrApi = false
    var translating = false
    
    let detailButton = UIButton()
    var translationDetails = [Dictionary<String, String>()]
    let closeButton = UIButton()
    let translateActivity = UIActivityIndicatorView()
    
    
    //Motion
    let motionManager = CMMotionManager()
    let motionThreshold : Double = 0.15
    var numSteady = 0
    var steady = false

    //State Variables - Which API to call & details about it
    var camState = 0
    var camDetails = ":-)"
    var menuButton = UIButton()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.previewView = UIView(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height));
        self.previewView.contentMode = UIViewContentMode.ScaleAspectFit
        self.view.addSubview(previewView);
        
        configureTapActions()
        setUpFaceDetector()
        setUpTextDetector()
        
        self.setupAVCapture()
        
        setUpMotionDetector()
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
    
    ///////////////////// STRUCTS ///////////////////////////////
    
    //Stores the information about a face
    struct face {
        var id = Int()
        var caption = String()
        var box:FaceDetectionBox
        var inFrame = Bool()
        
        init(id: Int, frame: CGRect, caption: String) {
            
            box = FaceDetectionBox(frame: frame, caption: caption)

            self.caption = caption
            self.id = id
            self.inFrame = true
            
        }
        
        init() {
            box = FaceDetectionBox()
        }
        
        mutating func update(frame: CGRect) {
            self.box.outline.frame = frame
            self.box.caption.frame = CGRect(x: frame.minX, y: frame.maxY, width: frame.width, height: 24)
        }
        
        mutating func compare(frame: CGRect) -> Bool {
            
            if(withinFifteen(frame.minX, two: self.box.outline.frame.minX) && withinFifteen(frame.minY, two: self.box.outline.frame.minY)) {
                update(frame)
                inFrame = true
                return true
            }
            return false
        }
        
        mutating func setTitle(caption: String) {
            self.caption = caption
            self.box.caption.text = caption
        }
        
        //This checks to see if two numbers are within fifteen of each other
        //This is for updating the FaceDetectionBoxes with celebrity names
        func withinFifteen(one: CGFloat, two: CGFloat) -> Bool {
            if(two == one) {
                return true
            }
            if(two + 30.0 > one && two < one) {
                return true
            }
            if(one + 30.0 > two && one < two) {
                return true
            }
            return false
        }
    }
    
    ////////////////// CORE MOTION //////////////////////////////
    
    func setUpMotionDetector() {
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.gyroUpdateInterval = 0.1
        
        motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue.currentQueue()!, withHandler: {(accelerometerData: CMAccelerometerData?, error:NSError?)in
            self.outputAccelerationData(accelerometerData!.acceleration)
            if (error != nil)
            {
                print("\(error)")
            }
        })
        
        motionManager.startGyroUpdatesToQueue(NSOperationQueue.currentQueue()!, withHandler: {(gyroData: CMGyroData?, error: NSError?)in
            self.outputRotationData(gyroData!.rotationRate)
            if (error != nil)
            {
                print("\(error)")
            }
        })
    }
    
    func outputAccelerationData(acceleration:CMAcceleration)
    {
        
        if(acceleration.x < motionThreshold && acceleration.y < motionThreshold && acceleration.z < motionThreshold) {
            numSteady += 1
            if(!steady && (numSteady == 10 || numSteady == 11)) {
                steady = true
            }
            
        } else {
            numSteady = 0
            steady = false
        }
        
    }
    
    func outputRotationData(rotation:CMRotationRate)
    {
        if(rotation.x < motionThreshold && rotation.y < motionThreshold && rotation.z < motionThreshold) {
            numSteady += 1
            if(!steady && (numSteady == 10 || numSteady == 11)) {
                steady = true
            }
            
        } else {
            numSteady = 0
            steady = false
        }
    }
    
    /////////////////// POPOVERS ////////////////////////////////
    
    func adaptivePresentationStyleForPresentationController(
        controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
    
    func showTranslations(sender: AnyObject) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("ttvc") as! TranslationTableViewController
        
        controller.preferredContentSize = CGSizeMake(300, 225)
        
        controller.details = self.translationDetails
        
        controller.modalPresentationStyle = UIModalPresentationStyle.Popover
        
        let popoverPresentationController = controller.popoverPresentationController
        
        popoverPresentationController!.sourceView = self.view
        popoverPresentationController!.sourceRect = sender.frame
        
        popoverPresentationController!.permittedArrowDirections = .Any
        popoverPresentationController!.delegate = self
        
        self.presentViewController(controller, animated: true, completion: nil)
    }
    
    ////////////////// JSON PARSING /////////////////////////////
    
    //this is called after the analyze image api is used
    func displayAnswers(rs: String, ids: [Int], coordinates: [[Int: CGPoint]]) {
        let dict = (convertStringToDictionary(rs)!)
        
        if(self.camState == 0) {
            if let facesInImage = dict["faces"] as? [NSDictionary] {
                if(facesInImage.isEmpty) {
                    print("No Faces")
                } else {
                    for face in facesInImage {
                        let caption: String = String(face["age"] as! Int) + " y/o " + (face["gender"] as! String)
                        
                        //checks all the the original points to see which is closest to the point returned from the API, gets back the face id
                        let id = comparePoints(CGPoint(x: face["faceRectangle"]!["left"] as! Int, y: face["faceRectangle"]!["top"] as! Int), ids: ids, coordinates: coordinates)
                        
                        //loops through all the faces to find the matching face
                        for i in 0 ..< faces.count {
                            
                            if(faces[i].id == id) {
                                
                                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), { () -> Void in
                                    self.faces[i].setTitle(caption)
                                    print("ID: \(id). Caption: " + caption)
                                    
                                })
                                
                                break
                            }
                        }
                    }
                }
                
                if(celebrityPresent) {
                    if let categories = dict["categories"] as? NSArray {
                        for i in 0 ..< categories.count {
                            if let details = categories[i]["detail"] as? NSDictionary {
                                if let celebrities = details["celebrities"] as? [NSDictionary] {
                                    for celeb in celebrities {
                                        
                                        let caption: String = (celeb["name"] as! String)
                                        
                                        //checks all the the original points to see which is closest to the point returned from the API, gets back the face id
                                        let id = comparePoints(CGPoint(x: celeb["faceRectangle"]!["left"] as! Int, y: celeb["faceRectangle"]!["top"] as! Int), ids: ids, coordinates: coordinates)
                                        
                                        //loops through all the faces to find the matching face
                                        for i in 0 ..< faces.count {
                                            
                                            if(faces[i].id == id) {
                                                
                                                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), { () -> Void in
                                                    self.faces[i].setTitle(caption)
                                                    print("ID: \(id). Caption: " + caption)
                                                    
                                                })
                                                
                                                break
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
        } else if(self.camState == 1) {
            
            var toTranslate = ""
            var originalText = [String]()
            //safely unwraps the json dictionary returned from the OCR API
            if let regions = dict["regions"] as? NSArray {
                for region in regions {
                    if let lines = region["lines"] as? NSArray {
                        for line in lines {
                            var str = ""
                            
                            if let words = line["words"] as? NSArray {
                                for word in words {
                                    str = str + " " + (word["text"] as! String)
                                }
                            }
                            
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
                    for i in 0 ..< originalText.count {
                        
                        let packet: Dictionary<String, String> = ["from": from, "original": originalText[i], "to": to, "translated": translated[i]]
                        self.translationDetails.append(packet)
                    }
                    
                    //Adds Buttons
                    self.view.addSubview(self.detailButton)
                    self.view.addSubview(self.closeButton)
                    self.translateActivity.stopAnimating()
                }
            }
        }
    }
    
    
    ///////////////////// CONFIGURE ACTIONS /////////////////////
    
    //adds the double tap to the view
    func configureTapActions() {
        doubleTap.numberOfTapsRequired = 2
        doubleTap.addTarget(self, action: #selector(SteadyViewFinderViewController.toggle(_:)))
        
        let tap = UISwipeGestureRecognizer(target: self, action: #selector(SteadyViewFinderViewController.takeStill(_:)))
        tap.delegate = self
        tap.direction = .Left
        self.view.addGestureRecognizer(tap)
    }
    
    
    //adds attributes to the buttons and adds some of them to the view
    func addButtons() {
        toggleButton.frame = CGRectMake(0, 20, 45, 25)
        toggleButton.addTarget(self, action: #selector(SteadyViewFinderViewController.toggle(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        let flipImage = UIImage(named:"FlipCameraButton.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        toggleButton.tintColor = UIColor.whiteColor()
        toggleButton.setImage(flipImage, forState: .Normal)
        //toggleButton.backgroundColor = UIColor.blackColor()
        self.view.addSubview(toggleButton)
        
        switchButton.frame = CGRect(x: self.view.frame.size.width - 80, y: self.view.frame.size.height - 60, width: 80, height: 60)
        switchButton.setTitle("PHOTO", forState: .Normal)
        switchButton.addTarget(self, action: #selector(SteadyViewFinderViewController.takeStill(_:)), forControlEvents: .TouchUpInside)
        //switchButton.backgroundColor = UIColor.whiteColor()
        switchButton.setTitleColor(UIColor.grayColor(), forState: .Normal)
        self.view.addSubview(switchButton)
        
        self.detailButton.frame = CGRect(x: self.view.frame.size.width - 40.0, y: 70.0, width: 34.0, height: 34.0)
        self.detailButton.setImage(UIImage(named: "detailButton.png"), forState: .Normal)
        self.detailButton.addTarget(self, action: #selector(SteadyViewFinderViewController.showTranslations(_:)), forControlEvents: .TouchUpInside)
        
        self.closeButton.frame = CGRect(x: self.view.frame.size.width - 40.0, y: 110.0, width: 34.0, height: 34.0)
        self.closeButton.setImage(UIImage(named: "closeButton.png"), forState: .Normal)
        self.closeButton.addTarget(self, action: #selector(SteadyViewFinderViewController.restartTranslation), forControlEvents: .TouchUpInside)
        
        //sets up the Menu Button
        menuButton.frame = CGRect(x: self.view.frame.size.width - 60, y: 20, width: 44, height: 44)
        if(camState == 1) {
            let index: String.Index = camDetails.startIndex.advancedBy(2) // Swift 2
            var ss2:String = camDetails.substringToIndex(index) // "Stack"
            ss2 = ss2.uppercaseString
            menuButton.setTitle(ss2, forState: .Normal)
        } else {
            menuButton.setTitle(camDetails, forState: .Normal)
        }
        menuButton.titleLabel?.textColor = UIColor.blackColor()
        menuButton.titleLabel?.adjustsFontSizeToFitWidth = true
        menuButton.tintColor = UIColor.blackColor()
        menuButton.addTarget(self, action: #selector(ImageCaptureViewController.showMenu(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(menuButton)
        
        translateActivity.center = CGPoint(x: detailButton.frame.midX, y: detailButton.frame.midY)
        translateActivity.activityIndicatorViewStyle = .Gray
        translateActivity.hidesWhenStopped = true
        self.view.addSubview(translateActivity)
        translateActivity.stopAnimating()
    }
    
    ///////////////////// FACE DETECTOR /////////////////////////
    
    
    //sets up the detector to track faces
    func setUpFaceDetector() {
        context = CIContext()
        options = [String : AnyObject]()
        options![CIDetectorAccuracy] = CIDetectorAccuracyLow
        
        detector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: options)
    }
    
    /* returns an array of features
     If the array is empty then there are no faces in the screen
     If it is not empty then there are as many faces as the return array.count */
    func getFacialFeatures(image: CIImage) -> [CIFeature] {
        let imageOptions = [CIDetectorImageOrientation : 6]
        return detector!.featuresInImage(image, options: imageOptions)
    }
    
    ///////////////////// TEXT DETECTOR /////////////////////////
    
    func setUpTextDetector() {
        textDetector = CIDetector(ofType: CIDetectorTypeText, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    }
    
    func getTextFeatures(image: CIImage) -> [CIFeature] {
        let imageOptions = [CIDetectorImageOrientation : 6]
        return textDetector!.featuresInImage(image, options: imageOptions)
    }
    
    func restartTranslation() {
        closeButton.removeFromSuperview()
        detailButton.removeFromSuperview()
        translationDetails = [Dictionary <String,String>()]
        numSteady = 0
        steady = false
        translating = false
    }
    
    ////////////////////////// MENU /////////////////////////////
    
    //setter method for the language code
    func changeState(state: Int, details: String) {
        self.camDetails = details
        self.camState = state
        
        print(camDetails)
        
        if(camState == 1) {
            let index: String.Index = camDetails.startIndex.advancedBy(2) // Swift 2
            var ss2:String = camDetails.substringToIndex(index) // "Stack"
            ss2 = ss2.uppercaseString
            menuButton.setTitle(ss2, forState: .Normal)
        } else {
            menuButton.setTitle(camDetails, forState: .Normal)
        }
    }
    
    //displays the language changing menu
    func showMenu(sender: AnyObject) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("menu") as! MenuViewController
        
        controller.camState = self.camState
        controller.camDetails = self.camDetails
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
    
    ///////////////////// CAMERA METHODS ////////////////////////
    
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
    
    //runs almost every frame (?) and draws face boxes
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        let image = getImageFromBuffer(sampleBuffer)
        
        var features = [CIFeature]()
        
        if(camState == 0) {
            features = self.getFacialFeatures(image)
        } else if(camState == 1) {
            features = self.getTextFeatures(image)
        }
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        
        let cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription!, false)
        
        var ids = [Int]()
        var coords = [[Int: CGPoint]]()
        
        if(steady) {

            //creates and draws face boxes
            dispatch_async(dispatch_get_main_queue()) {

                if(self.camState == 0) {
                    self.removeBoxes()     //deletes the unused boxes
                    for i in 0 ..< features.count {
                        
                        //creates the frame for the face
                        let frame = self.transformFacialFeaturePosition(features[i].bounds.minX, yPosition: features[i].bounds.minY, width: features[i].bounds.width, height: features[i].bounds.height, videoRect: cleanAperture, previewRect: self.cameraPreview.frame, isMirrored: !(self.back))
                        
                        //checks that frame to see if it matches a face
                        var foundFace = false
                        for i in 1 ..< self.faces.count {
                            if(self.faces[i].compare(frame)) {
                                foundFace = true
                                break
                            }
                        }
                        
                        //if the frame couldn't be matched, create a new face
                        if(!foundFace) {
                            
                            let id = self.totalFacesDetected
                            self.totalFacesDetected += 1
                            
                            let f = SteadyViewFinderViewController.face(id: id, frame: frame, caption: "Person")
                            self.faces.append(f)
                            
                            ids.append(id)
                            coords.append([id: frame.origin])
                            
                            if(i == features.count - 1) {
                                self.takePicture(ids, coordinates: coords)
                            }
                        }
                    }
                    self.drawBoxes()
                } else if(self.camState == 1) {
                    if(!self.translating) {
                        if(features.count > 0) {
                            self.translateActivity.startAnimating()
                            self.takePicture([0], coordinates: [[0: CGPoint(x: 0,y: 0)]])
                            self.translating = true
                        }
                    }
                }
            }
        } else if(faces.count > 1) {
           
            //If the camera isn't steady but it's detected a face that is in the frame, this code will run. Updates boxes for already
            //  discovered faces without discovering a new one
            
            //creates and draws face boxes
            dispatch_async(dispatch_get_main_queue()) {
                
                self.removeBoxes()
                for face in features {
                    let frame = self.transformFacialFeaturePosition(face.bounds.minX, yPosition: face.bounds.minY, width: face.bounds.width, height: face.bounds.height, videoRect: cleanAperture, previewRect: self.cameraPreview.frame, isMirrored: !(self.back))
                    for i in 1 ..< self.faces.count {
                        if(self.faces[i].compare(frame)) {
                            break
                        }
                    }
                }
                
                self.drawBoxes()
            }
        }
    }
    
    //takes the picture to be sent to the API
    //IMPORTANT: Change THIS method when adding in multiple APIs
    func takePicture(ids: [Int], coordinates: [[Int: CGPoint]]) {
        let videoConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        if videoConnection != nil {
            
            // Secure image
            stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                
                let image = UIImage(data: imageData)
                
                var fields = ""
                
                if(self.camState == 0) {
                    // self.analyzeImage(image!) //calls analyze image API
                    self.captionLabel.text = "Generating Caption..."
                    
                    if(self.camDetails == ":-)") {
                        fields = "?visualFeatures=Faces,Description,Categories"
                    } else if(self.camDetails == "B-)") {
                        fields = "?visualFeatures=Faces,Description,Categories&details=Celebrities"
                    }
                } else if(self.camState == 1) {
                    self.captionLabel.text = "Getting Translation..."
                }
                
                let api = API(state: self.camState, header: ["Ocp-Apim-Subscription-Key": "dca2b686d07a4e18ba81f5731053dbab", "Content-Type": "application/octet-stream"], body: UIImageJPEGRepresentation(image!, 0.9)!, fields: fields)
                
                api.callAPI() { (rs: String) in
                    if(rs.containsString("celebrities")) {
                        self.celebrityPresent = true
                    } else {
                        self.celebrityPresent = false
                    }
                    self.displayAnswers(rs, ids: ids, coordinates: coordinates)
                }
            }
        }
    }
    
    //returns the frame for the face box
    private func transformFacialFeaturePosition(xPosition: CGFloat, yPosition: CGFloat, width: CGFloat, height: CGFloat, videoRect: CGRect, previewRect: CGRect, isMirrored: Bool) -> CGRect {
        
        var featureRect = CGRect(origin: CGPoint(x: xPosition, y: yPosition), size: CGSize(width: width, height: height))
        let widthScale = previewRect.size.width / videoRect.size.height
        let heightScale = previewRect.size.height / videoRect.size.width
        
        let transform = isMirrored ? CGAffineTransformMake(0, heightScale, -widthScale, 0, previewRect.size.width, 0) :
            CGAffineTransformMake(0, heightScale, widthScale, 0, 0, 0)
        
        featureRect = CGRectApplyAffineTransform(featureRect, transform)
        
        featureRect = CGRectOffset(featureRect, previewRect.origin.x, previewRect.origin.y)
        
        return featureRect
    }
    
    //calls the segue to move to the ImageCaptureViewController
    func takeStill(sender: AnyObject) {
        self.stopCamera()
        performSegueWithIdentifier("takeStill", sender: nil)
    }
    
    //Touch to focus
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = touches.first!
        super.touchesBegan(touches, withEvent: event)
        
        let touchedPoint = touch.locationInView(cameraPreview)
        
        
        let newPoint = CGPoint(x: 480 * (touchedPoint.x / self.view.frame.size.width), y: 640 * (touchedPoint.y / self.view.frame.size.height))
        
        self.focusAtPoint(newPoint)
    }
    
    ///////////////////// HELPER METHODS ////////////////////////
    
    //This method compares one point to an array of type Dictionary<Int: CGPoint>
    //It returns the ID of the point closes to the given point
    func comparePoints(point: CGPoint, ids: [Int], coordinates: [[Int: CGPoint]]) -> Int {

        var currentStoretest:CGFloat = 1500.0
        var shortestId = 0
        
        for i in 0 ..< ids.count {
            //pythagorean theorum to calculate distance between points
            let testPoint = coordinates[i][ids[i]]! as CGPoint
            
            let xDist = abs(point.x - testPoint.x)
            let yDist = abs(point.y - testPoint.y)
            
            let distance = (xDist * xDist) + (yDist * yDist)
            
            //updates the shortest, keeps track of distance and id of current closest point
            if(i == 0) {
                currentStoretest = distance
                shortestId = ids[0]
            } else if(distance < currentStoretest) {
                shortestId = ids[i]
                currentStoretest = distance
            }
        }
        
        return shortestId
    }
    
    //resizes a frame
    func resizeFrame(x: Int, y: Int, height: Int, width: Int) -> CGRect {
        let resizedHeight = self.view.frame.size.height * (self.view.frame.size.width / 480.0)
        
        let newX = Int(self.view.frame.size.width * (CGFloat(x) / 480.0))
        let newY = Int(resizedHeight * (CGFloat(y) / 640.0))
        let newHeight = Int(resizedHeight * (CGFloat(height) / 640.0))
        let newWidth = Int(self.view.frame.size.width * (CGFloat(width) / 480.0))
        
        let frame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        return frame
    }
    
    //gets rid of all the face boxes on the screen
    func removeBoxes() {
        for i in 1 ..< faces.count {
            
            //checks to see if face is in frame. If yes - sets inFrame to false. If no - removes from superview and faces array
            if(!faces[i].inFrame) {
                faces[i].box.removeFromSuperview()
                faces.removeAtIndex(i)
                removeBoxes()                   //Recurses because i cannot be changed, was throwing exceptions
                break
            } else {
                faces[i].inFrame = false
            }
        }
    }
    
    //draws all faces in the faces array
    func drawBoxes() {
        for face in faces {
            self.view.addSubview(face.box)
        }
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


//////////////////////// CAMERA EXTENSION ///////////////////

// AVCaptureVideoDataOutputSampleBufferDelegate protocol and related methods
extension SteadyViewFinderViewController:  AVCaptureVideoDataOutputSampleBufferDelegate{
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
            //break;
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