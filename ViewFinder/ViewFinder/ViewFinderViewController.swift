//
//  ViewFinderViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/23/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 * This is the original and now obsolete ViewFinder. In this verison,
 * it has the capability for face detection. To track these faces it 
 * checks to see if the same face is within a certain distance of a 
 * face it detected in the previous frame.
 */

import Foundation
import UIKit
import AVFoundation
import CoreMotion
import CoreImage

class ViewFinderViewController: UIViewController, UIGestureRecognizerDelegate {
    
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
    var faceBoxes = [FaceDetectionBox]()
    var textBoxes = [TranslateWordBox]()
    var faces = [ViewFinderViewController.face()]
    //var faceFeatures
    var totalFacesDetected = 0
    
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
    
    //Text Detector
    var textDetector: CIDetector?
    var textDetectorOptions: [String : AnyObject]?
    var textContext: CIContext?
    var hasText = false
    //var callOcrApi = false
    var hasCalledTranslateAPI = false
    let indicator = UIActivityIndicatorView()

    var face = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.previewView = UIView(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height));
        self.previewView.contentMode = UIViewContentMode.ScaleAspectFit
        self.view.addSubview(previewView);
        
        configureTapActions()

        setUpFaceDetector()
        
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
    
 ///////////////////// STRUCTS ///////////////////////////////

    //Stores the information about a face
    struct face {
        var id = Int()
        var lastX = Int()
        var lastY = Int()
        var caption = String()
        
        init(id: Int, x: Int, y: Int) {
            self.id = id
            self.lastX = x
            self.lastY = y
            self.caption = String(id)
        }
        
        init(id: Int, x: Int, y: Int, caption: String) {
            self.id = id
            self.lastX = x
            self.lastY = y
            self.caption = caption
        }
        
        init() {
            
        }
        
        mutating func update(frame: CGRect) {
            self.lastX = Int(frame.minX)
            self.lastY = Int(frame.minY)
        }
        
        mutating func compare(frame: CGRect) -> Bool {
            if(withinFifteen(Int(frame.minX), two: lastX) && withinFifteen(Int(frame.minY), two: lastY)) {
                update(frame)
                return true
            }
            return false
        }
        
        //This checks to see if two numbers are within fifteen of each other
        //This is for updating the FaceDetectionBoxes with celebrity names
        func withinFifteen(one: Int, two: Int) -> Bool {
            if(two == one) {
                return true
            }
            if(two + 30 > one && two < one) {
                return true
            }
            if(one + 30 > two && one < two) {
                return true
            }
            return false
        }
    }
    
    
////////////////// JSON PARSING ///////////////////////
    
    //this is called after the analyze image api is used
    func displayAnswers(rs: String, id: Int) {
        let dict = (convertStringToDictionary(rs)!)
        
        if let facesInImage = dict["faces"] as? [NSDictionary] {
            if(facesInImage.isEmpty) {
                print("No Faces")
            } else {
                for face in facesInImage {
                    let caption: String = String(face["age"] as! Int) + " y/o " + (face["gender"] as! String)
                    for i in 0 ..< faces.count {
                        if(faces[i].id == id) {
                            faces[i].caption = caption
                        }
                    }
                    for box in faceBoxes {
                        box.caption.text = updateBoxText(box)
                    }
                }
            }
        } else {
            print("Could not get Faces")
        }
    }
    
 ///////////////////// API CALLS /////////////////////////////
    
    
    //calls the analyze image API
    func analyzeImage(image: UIImage, id: Int) {
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
                    self.displayAnswers(responseString as String, id: id)
                    
                } else {
                
                }
            }
            
        }
        task.resume()
    }

 ///////////////////// CONFIGURE ACTIONS /////////////////////
    
    //adds the double tap to the view
    func configureTapActions() {
        doubleTap.numberOfTapsRequired = 2
        doubleTap.addTarget(self, action: #selector(ViewFinderViewController.toggle(_:)))
        
        let tap = UISwipeGestureRecognizer(target: self, action: #selector(ViewFinderViewController.takeStill(_:)))
        tap.delegate = self
        tap.direction = .Left
        self.view.addGestureRecognizer(tap)
    }
    
    
    
    //adds attributes to the buttons and adds some of them to the view
    func addButtons() {
        toggleButton.frame = CGRectMake(0, 20, 45, 25)
        toggleButton.addTarget(self, action: #selector(ViewFinderViewController.toggle(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        let flipImage = UIImage(named:"FlipCameraButton.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        toggleButton.tintColor = UIColor.whiteColor()
        toggleButton.setImage(flipImage, forState: .Normal)
        //toggleButton.backgroundColor = UIColor.blackColor()
        self.view.addSubview(toggleButton)
        
        switchButton.frame = CGRect(x: self.view.frame.size.width - 80, y: self.view.frame.size.height - 60, width: 80, height: 60)
        switchButton.setTitle("PHOTO", forState: .Normal)
        switchButton.addTarget(self, action: #selector(ViewFinderViewController.takeStill(_:)), forControlEvents: .TouchUpInside)
        //switchButton.backgroundColor = UIColor.whiteColor()
        switchButton.setTitleColor(UIColor.grayColor(), forState: .Normal)
        self.view.addSubview(switchButton)
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
        
        let features = self.getFacialFeatures(image)
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        
        let cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription!, false)
        
        //creates and draws face boxes
        dispatch_async(dispatch_get_main_queue()) {
            self.removeBoxes()
            for face in features {
                let frame = self.transformFacialFeaturePosition(face.bounds.minX, yPosition: face.bounds.minY, width: face.bounds.width, height: face.bounds.height, videoRect: cleanAperture, previewRect: self.cameraPreview.frame, isMirrored: !(self.back))
                let box = FaceDetectionBox(frame: frame, caption: "Person")
                
                self.faceBoxes.append(box)
            }
            
            self.drawBoxes(features)
        }
    }
    
    func takePicture(id: Int) {
        let videoConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        if videoConnection != nil {
            
            // Secure image
            stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                
                let image = UIImage(data: imageData)
                
                self.analyzeImage(image!, id: id) //calls analyze image API
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
        for box in faceBoxes {
            box.removeFromSuperview()
        }
        
        if(faceBoxes.count == 0) {
            faces = [ViewFinderViewController.face()]
        }
        
        faceBoxes = [FaceDetectionBox]()
    }
    
    //draws all face boxes in the faceBoxes array
    func drawBoxes(features: [CIFeature]) {
        for box in faceBoxes {
            let name = updateBoxName(box, features: features)
            box.caption.text = name
            self.view.addSubview(box)
        }
    }
    
    func updateBoxText(box: FaceDetectionBox) -> String {
        for i in 1 ..< faces.count {
            if(faces[i].compare(box.frame)) {
                return faces[i].caption
            }
        }
        return ""
    }
    
    func updateBoxName(box: FaceDetectionBox, features: [CIFeature]) -> String {
        
        if(faces.count > 2) {

        }
        
        //uses face comparison method, checks to see if face is within circle w/ radius 21.2 pixels
        for i in 1 ..< faces.count {
            if(faces[i].compare(box.outline.frame)) {
                return faces[i].caption
            }
        }
        
        /*
 
         Compare to stored faces?????
 
        */
        
        let id = totalFacesDetected
        totalFacesDetected += 1

        let f = ViewFinderViewController.face.init(id: id, x: Int(box.outline.frame.minX), y: Int(box.outline.frame.minY))
        faces.append(f)
        
        takePicture(id)
        
        return String(id)
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
extension ViewFinderViewController:  AVCaptureVideoDataOutputSampleBufferDelegate{
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

