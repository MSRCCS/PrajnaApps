//
//  TensorflowViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/30/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 * This is the ViewFinder View Controller with Tensorflow Incorporated.
*/

import Foundation
import UIKit
import CoreImage
import CoreMotion
import AVFoundation


class TensorflowViewController: UIViewController, UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate, TensorflowMenuDelegate {

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
    var faces = [TensorflowViewController.face()]
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
    var camState = 2
    var camDetails = "tf"
    var detailLabel = UILabel()
    var menuButton = UIButton()
    
    //Tensorflow
    var labels = [ObjectCaptionLabel]()
    var loaded = false
    var numLabels = 0
    let debugImageView = UIImageView()
    let debugButton = UIButton()
    let dismissDebugImageButton = UIButton()
    var currentImage: CGImage!;
    let instructionButton = UIButton()
    
    var timeOutTimer = NSTimer()
    
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
        
        setUpTensorflow()
        
        timeOutTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(self.testIfRunning(_:)), userInfo: nil, repeats: true)
        
        self.tabBarController?.tabBar.hidden = true
    }
    
    func testIfRunning(sender: NSTimer) {
        if(session.running) {
        } else {
            session.stopRunning()
            session.startRunning()
        }
    }

    override func viewWillAppear(animated: Bool) {
        if !done {
            session.startRunning();
        }
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if(firstTime) {
            showInstructions(instructionButton)
            firstTime = false
        }
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
    
    ///////////////////// TENSORFLOW ////////////////////////////
    
    //loads neural network for tensorflow and adds labels to the view
    func setUpTensorflow() {
        var loadedModel = false
        var loadedlabels = false
        
        let alertController = UIAlertController(title: "Uh Oh!", message:
            "--", preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
        
        
        
        let loadModel = self.LoadModel("tensorflow_inception_graph", second: "pb")
        if(loadModel == "OK") {
            loadedModel = true
        } else {
            //send alert with fail
            alertController.message = loadModel
            self.presentViewController(alertController, animated: true, completion: nil)
        }        
        
        let loadLabel = self.LoadLabel("imagenet_comp_graph_label_strings", second: "txt")
        if(loadLabel == "OK") {
            loadedlabels = true
        } else {
            alertController.message = loadLabel
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        
        if(loadedModel && loadedlabels) {
            print("Loaded")
            self.loaded = true
        }
        
        for i in 0..<5 {
            let ocl = ObjectCaptionLabel(pos: i, caption: "", value: 0.0)
            labels.append(ocl)
        }
    }
    
    //displays/removes the object detection labels from tensorflow
    func displayLabels(dictionary: NSMutableDictionary) {
        var count = 0
        var remove = true
        
        var values = dictionary.allValues as! [Float]
        values.sortInPlace()
        values = values.reverse()
        
        for value in values {
            for d in dictionary {
                if(d.value as! Float == value) {
                    //setValue(value * 100.0, forKey: prediction.key as! String)
                    
                    if(count < 5) {
                        self.labels[count].captionLabel.text = String(d.key)
                        
                        var valueString = String(value * 100.0)
                        valueString = valueString.substringToIndex(valueString.startIndex.advancedBy(4))
                        
                        self.labels[count].valueLabel.text = String(valueString)
                        
                        if(count >= numLabels - 1) {
                            self.view.addSubview(self.labels[count])
                            remove = false
                        }
                        count += 1
                    }
                    
                    break
                }
            }
        }
        
        if(remove) {
            for i in count..<numLabels {
                self.labels[i].removeFromSuperview()
            }
        }
        numLabels = count
        
        if(camState != 2) {
            for label in labels {
                label.removeFromSuperview()
            }
            numLabels = 0
        }
    }
    
    //samples and displays the image that is running through the tensorflow neural network
    func debugImage(sender: UIButton) {
        
        stopCamera()
        self.view.addSubview(debugImageView)
        self.view.addSubview(dismissDebugImageButton)
        
        //samples image like Tensorflow does
        
        let inputCGImage = currentImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = CGImageGetWidth(inputCGImage)
        let height = CGImageGetHeight(inputCGImage)
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = RGBA32.bitmapInfo

        let context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo)
        
        CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), inputCGImage)

        let resizedContext = CGBitmapContextCreate(nil, 224, 224, bitsPerComponent, 224 * bytesPerPixel, colorSpace, bitmapInfo)

        let ogPixelBuffer = UnsafeMutablePointer<RGBA32>(CGBitmapContextGetData(context))
        let outPixelBuffer = UnsafeMutablePointer<RGBA32>(CGBitmapContextGetData(resizedContext))
        
        for y in 0 ..< 224 {
            for x in 0 ..< 224 {
                let in_x = (y * width) / 224
                let in_y = (x * height) / 224
                let ogPixel = ogPixelBuffer + ((in_y * width) + (in_x))
                let outPixel = outPixelBuffer + 224 + (y * 224 - x)
                let color = RGBA32(red: (ogPixel.memory.red()), green: (ogPixel.memory.green()), blue: (ogPixel.memory.blue()), alpha: 255)
                outPixel.memory = color
            }
        }

        let outputCGImage = CGBitmapContextCreateImage(resizedContext)
        let outImage = UIImage(CGImage: outputCGImage!)
        
        debugImageView.image = outImage
        //set image for image view
        //show labels
    }
    
    struct RGBA32 {
        var color: UInt32
        
        func red() -> UInt8 {
            return UInt8((color >> 24) & 255)
        }
        
        func green() -> UInt8 {
            return UInt8((color >> 16) & 255)
        }
        
        func blue() -> UInt8 {
            return UInt8((color >> 8) & 255)
        }
        
        func alpha() -> UInt8 {
            return UInt8((color >> 0) & 255)
        }
        
        init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
            color = (UInt32(red) << 24) | (UInt32(green) << 16) | (UInt32(blue) << 8) | (UInt32(alpha) << 0)
        }
        
        static let bitmapInfo = CGImageAlphaInfo.PremultipliedLast.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue
    }
    
    func doneDebugging(sender: AnyObject) {
        debugImageView.removeFromSuperview()
        dismissDebugImageButton.removeFromSuperview()
        restartCamera()
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
            inFrame = true
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
    
    func outputAccelerationData(acceleration:CMAcceleration) {
        
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
    
    func outputRotationData(rotation:CMRotationRate) {
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
        
        let storyboard = UIStoryboard(name: "Tensorflow", bundle: nil)
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
    
    func showInstructions(sender: AnyObject) {

        let storyboard = UIStoryboard(name: "Tensorflow", bundle: nil)
        
        let instructionVC = storyboard.instantiateViewControllerWithIdentifier("Instructions") as! InstructionsViewController
        instructionVC.preferredContentSize = CGSize(width: 300, height: 360)
        
        instructionVC.modalPresentationStyle = UIModalPresentationStyle.Popover

        let popoverPresentationController = instructionVC.popoverPresentationController
        
        popoverPresentationController!.sourceView = self.view
        popoverPresentationController!.sourceRect = sender.frame
        
        popoverPresentationController!.permittedArrowDirections = .Any
        popoverPresentationController!.delegate = self
        
        self.presentViewController(instructionVC, animated: true, completion: nil)
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
                            print("BoundingBox: \(line["boundingBox"])")
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
            } else {
                self.translateActivity.stopAnimating()
                self.restartTranslation()
            }
        }
    }
    
    ///////////////////// CONFIGURE ACTIONS /////////////////////
    
    //adds the double tap to the view
    func configureTapActions() {
        doubleTap.numberOfTapsRequired = 2
        doubleTap.addTarget(self, action: #selector(TensorflowViewController.toggle(_:)))
        
        let tap = UISwipeGestureRecognizer(target: self, action: #selector(TensorflowViewController.takeStill(_:)))
        tap.delegate = self
        tap.direction = .Left
        self.view.addGestureRecognizer(tap)
    }
    
    //adds attributes to the buttons and adds some of them to the view
    func addButtons() {
        toggleButton.frame = CGRectMake(0, 20, 50, 40)
        toggleButton.addTarget(self, action: #selector(TensorflowViewController.toggle(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        let flipImage = UIImage(named:"FlipCameraButton.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        toggleButton.tintColor = UIColor.whiteColor()
        toggleButton.setImage(flipImage, forState: .Normal)
        self.view.addSubview(toggleButton)
        
        switchButton.frame = CGRect(x: self.view.frame.size.width - 50, y: self.view.frame.size.height - 40, width: 40, height: 30)
        let camImage = UIImage(named: "CameraButton.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        switchButton.tintColor = UIColor.whiteColor()
        switchButton.addTarget(self, action: #selector(TensorflowViewController.takeStill(_:)), forControlEvents: .TouchUpInside)
        switchButton.setImage(camImage, forState: .Normal)
        self.view.addSubview(switchButton)
        
        self.detailButton.frame = CGRect(x: self.view.frame.size.width - 40.0, y: 70.0, width: 34.0, height: 34.0)
        self.detailButton.setImage(UIImage(named: "detailButton.png"), forState: .Normal)
        self.detailButton.addTarget(self, action: #selector(TensorflowViewController.showTranslations(_:)), forControlEvents: .TouchUpInside)
        
        self.closeButton.frame = CGRect(x: self.view.frame.size.width - 40.0, y: 110.0, width: 34.0, height: 34.0)
        self.closeButton.setImage(UIImage(named: "closeButton.png"), forState: .Normal)
        self.closeButton.addTarget(self, action: #selector(TensorflowViewController.restartTranslation), forControlEvents: .TouchUpInside)
        
        //sets up the Menu Button
        menuButton.frame = CGRect(x: self.view.frame.size.width - 45, y: 20, width: 40, height: 40)
        menuButton.setImage(UIImage(named: "MenuButton.png"), forState: .Normal)
        menuButton.addTarget(self, action: #selector(TensorflowViewController.showMenu(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(menuButton)
        
        translateActivity.center = CGPoint(x: detailButton.frame.midX, y: detailButton.frame.midY)
        translateActivity.activityIndicatorViewStyle = .Gray
        translateActivity.hidesWhenStopped = true
        self.view.addSubview(translateActivity)
        translateActivity.stopAnimating()

        debugButton.frame = CGRect(x: 0, y: self.view.frame.size.height - 44, width: 80, height: 44)
        debugButton.titleLabel?.textColor = UIColor.blackColor()
        debugButton.setTitleColor(UIColor.blackColor(), forState: .Normal)
        debugButton.setTitle("DEBUG", forState: .Normal)
        debugButton.addTarget(self, action: #selector(self.debugImage(_:)), forControlEvents: .TouchUpInside)

        debugImageView.frame = CGRect(x: 0, y: self.view.frame.size.height - 268, width: 224, height: 224)
        
        dismissDebugImageButton.frame = CGRect(x: 0, y: self.view.frame.size.height - 44, width: 80, height: 44)
        dismissDebugImageButton.backgroundColor = UIColor.redColor()
        dismissDebugImageButton.setTitle("DISMISS", forState: .Normal)
        dismissDebugImageButton.addTarget(self, action: #selector(TensorflowViewController.doneDebugging(_:)), forControlEvents: .TouchUpInside)
        
        instructionButton.frame = CGRect(x: (self.view.frame.width / 2) - 20, y: 20, width: 40, height: 40)
        let instructionImage = UIImage(named: "InstructionsButton.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        instructionButton.tintColor = UIColor.whiteColor()

    
        instructionButton.setImage(instructionImage, forState: .Normal)
        instructionButton.addTarget(self, action: #selector(self.showInstructions(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(instructionButton)
        
        detailLabel.frame = CGRect(x: self.view.frame.size.width - 150, y: 20, width: 100, height: 40)
        detailLabel.numberOfLines = 2
        detailLabel.textColor = UIColor.whiteColor()
        detailLabel.text = "Object Detection"
        detailLabel.textAlignment = .Right
        detailLabel.font = UIFont(name: (detailLabel.font?.fontName)!, size: 12.0)
        self.view.addSubview(detailLabel)
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
        textDetector = CIDetector(ofType: CIDetectorTypeText, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
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
        
        //remove tensorflow objects from the screen
        if(camState == 2) {
            for label in labels {
                label.removeFromSuperview()
            }
            steady = false
            numSteady = 0
            numLabels = 0
                debugButton.removeFromSuperview()
        }
        
        self.camDetails = details
        self.camState = state

        if(camState == 0) {
            detailLabel.text = "Facial Recognition"
        } else if(camState == 1) {
            detailLabel.text = "Translating Into " + getLanguageFromCode(camDetails)
        } else {
            detailLabel.text = "Object Detection"
        }
    }
    
    //displays the language changing menu
    func showMenu(sender: AnyObject) {
        
        let storyboard = UIStoryboard(name: "Tensorflow", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("tfmenu") as! TensorflowMenu
        
        controller.preferredContentSize = CGSizeMake(180, 300)
        controller.modalPresentationStyle = UIModalPresentationStyle.Popover

        controller.delegate = self
        
        let popoverPresentationController = controller.popoverPresentationController
        popoverPresentationController!.sourceView = self.view
        popoverPresentationController!.sourceRect = menuButton.frame
        popoverPresentationController!.permittedArrowDirections = .Any
        popoverPresentationController!.delegate = self
        self.presentViewController(controller, animated: true, completion: {
            controller.setDetails(self.camState, camDetails: self.camDetails)
        })
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
        
        let context = CIContext(options: nil)
        
        self.currentImage = context.createCGImage(image, fromRect: image.extent)
        
        if(camState == 2) {
            if(loaded) {

                let pb : CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
                
                if let dict = runCNNOnFrame(pb) {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.displayLabels(dict)
                    })
                } else {
                    print("Couldn't get results")
                }
            }
        } else {
            
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
                            
                            var found = false
                            
                            let frame = self.transformFacialFeaturePosition(features[i].bounds.minX, yPosition: features[i].bounds.minY, width: features[i].bounds.width, height: features[i].bounds.height, videoRect: cleanAperture, previewRect: self.cameraPreview.frame, isMirrored: !(self.back))
                            
                            for l in 1 ..< self.faces.count {
                                
                                if (self.faces[l].id == Int((features as! [CIFaceFeature])[i].trackingID)) {
                                    
                                    self.faces[l].update(frame)
                                    found = true
                                }
                                // add face, turn on call to API
                            }
                            
                            if(!found) {
                                let id = Int((features as! [CIFaceFeature])[i].trackingID)
                                
                                let f = TensorflowViewController.face(id: id, frame: frame, caption: "Person")
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
                            if(Int((face as! CIFaceFeature).trackingID) == self.faces[i].id) {
                                self.faces[i].update(frame)
                            }
                        }
                    }
                    self.drawBoxes()
                }
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
        timeOutTimer.invalidate()
        //performSegueWithIdentifier("takeStill", sender: nil)
        if let tbc = self.tabBarController {
            tbc.selectedIndex = 1
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
extension TensorflowViewController:  AVCaptureVideoDataOutputSampleBufferDelegate{
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
        self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey:Int(kCVPixelFormatType_32BGRA)]
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
    
    // clean up AVCapture
    func restartCamera(){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.session.startRunning()
            self.done = true;
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