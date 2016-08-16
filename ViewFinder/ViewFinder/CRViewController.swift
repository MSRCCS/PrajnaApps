//
//  ViewController.swift
//  CropFaceTests
//
//  Created by Jacob Kohn on 8/1/16.
//  Copyright © 2016 Jacob Kohn. All rights reserved.
//


import Foundation
import UIKit
import AVFoundation
import CoreImage
import MobileCoreServices
import CoreData
import CoreMotion
import QuartzCore


class CRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var segButton = UIButton()
    var toggleButton = UIButton()
    var captureButton = UIButton()
    var uploadButton = UIButton()
    var switchButton = UIButton()
    let doubleTap = UITapGestureRecognizer()
    var swipe = UISwipeGestureRecognizer()
    var cover = UIView()
    var currentImage = UIImage()
    
    var boxView:UIView!;
    var previewView: UIView!;
    
    //Camera Capture requiered properties
    var videoDataOutput: AVCaptureVideoDataOutput!;
    var videoDataOutputQueue : dispatch_queue_t!;
    var previewLayer:AVCaptureVideoPreviewLayer!;
    var captureDevice : AVCaptureDevice!
    var frontDevice : AVCaptureDevice!
    var backDevice : AVCaptureDevice!
    let session=AVCaptureSession()
    let metadataOutput=AVCaptureMetadataOutput()
    let stillImageOutput = AVCaptureStillImageOutput()
    //let imageView = UIImageView()
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
    var detectorSet = false
    
    //Motion
    let motionManager = CMMotionManager()
    let motionThreshold : Double = 0.15
    var numSteady = 0
    var steady = false
    
    var detectedFaces = [NSManagedObject]()
    var detectedIDs = [Int]()
    
    //Face Detection Banners
    var banners = [FaceDetectionBanner]()
    var faces = [Int: Face]()
    
    override func viewDidLoad() {

        super.viewDidLoad()
        self.previewView = UIView(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height));
        self.previewView.contentMode = UIViewContentMode.ScaleAspectFit
        self.view.addSubview(previewView);
        
        configureTapActions()
        self.setupAVCapture()
        setUpFaceDetector()
        
        setUpMotionDetector()
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.segButton.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func viewWillAppear(animated: Bool) {
        if !done {
            session.startRunning();
        }
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        session.stopRunning()
        session.startRunning()
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
    
    struct Face {
        var name: String
        var frame: FaceRectangle
        var image = UIImage()
        var view = UIView()
        var present = Bool()
        
        init(bounds: CGRect) {
            frame = FaceRectangle(frame: bounds)
            name = "Person"
            image = UIImage()
            present = true
        }
        
        mutating func updateFrame(frame: CGRect) {
            UIView.animateWithDuration(0.1, animations: { () -> Void in
                self.frame.outline.frame = frame
                self.present = true
            })
        }
        
        mutating func setValues(name: String, image: UIImage) {
            self.name = name
            self.image = image
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
    
    /////////////////// CORE DATA //////////////////////////
    
    func saveFace(name: String, image: UIImage) {
        let appDelegate =
            UIApplication.sharedApplication().delegate as! AppDelegate
        
        let managedContext = appDelegate.managedObjectContext
        
        let entity =  NSEntityDescription.entityForName("Face",
                                                        inManagedObjectContext:managedContext)
        
        let person = NSManagedObject(entity: entity!,
                                     insertIntoManagedObjectContext: managedContext)
        
        let imageData = UIImageJPEGRepresentation(image, 1.0)
        person.setValue(name, forKey: "name")
        person.setValue(imageData!, forKey: "image")
        
        do {
            try managedContext.save()
            detectedFaces.append(person)
        } catch let error {
            print("Could not save \(error), \((error as NSError).userInfo)")
        }
    }

    /////////////////// CONFIGURE ACTIONS //////////////////
    
    //sets up the detector to track faces
    func setUpFaceDetector() {
        context = CIContext()
        options = [String : AnyObject]()
        options![CIDetectorAccuracy] = CIDetectorAccuracyLow
        options![CIDetectorTracking] = true
        detector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: options)
        detectorSet = true
    }
    
    /* returns an array of features
     If the array is empty then there are no faces in the screen
     If it is not empty then there are as many faces as the return array.count */
    func getFacialFeatures(image: CIImage) -> Bool {
        let imageOptions = [CIDetectorImageOrientation : 6]
        if(detector!.featuresInImage(image, options: imageOptions).count > 0) {
            return true
        }
        return false
    }
    
    //adds the double tap and swipe to the view
    func configureTapActions() {
        doubleTap.numberOfTapsRequired = 2
        doubleTap.addTarget(self, action: #selector(self.toggle(_:)))
    }
    
    //adds attributes to the buttons and adds some of them to the view
    func addButtons() {
        
        let cover = UIView(frame: CGRect(x: 0, y: previewView.bounds.maxY, width: self.view.frame.size.width, height: self.view.frame.size.height - previewView.bounds.height))
        cover.backgroundColor = UIColor.blackColor()
        self.view.addSubview(cover)
        
        
        //sets up the capture button
        captureButton.frame = CGRectMake(self.view.frame.width / 2 - 45, self.view.frame.height - 110, 90, 90)
        let captureImage = UIImage(named: "CaptureButtonPNG.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        captureButton.tintColor = UIColor.whiteColor()
        captureButton.setImage(captureImage, forState: .Normal)
        captureButton.addTarget(self, action: #selector(self.takePicture(_:)), forControlEvents: .TouchUpInside)
        //self.view.addSubview(captureButton)
        
        segButton = UIButton(frame: CGRect(x: self.view.frame.size.width - 70, y: self.view.frame.size.height - 70, width: 60, height: 60))
        segButton.setTitle("Faces", forState: .Normal)
        segButton.addTarget(self, action: #selector(self.showFaces(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(segButton)
    }
    
    /////////////////// CAMERA METHODS ////////////////////
    
    var frames = 5
    //runs almost every frame (?)
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        let cim = getImageFromBuffer(sampleBuffer)
        if detectorSet {
            if getFacialFeatures(cim) {
                if (frames % 5 == 0) {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.setFacesToNotPresent()
                    })
                    let imageOptions = [CIDetectorImageOrientation : 6]
                    let faces = self.detector!.featuresInImage(cim, options: imageOptions)
                    for f in faces {
                        let face = f as! CIFaceFeature
                        let id = Int(face.trackingID)
                        
                        if self.faces[id] != nil {
                            let frame = self.transformFacialFeaturePosition(face.bounds.minX, yPosition: face.bounds.minY, width: face.bounds.width, height: face.bounds.height, previewRect: self.cameraPreview.frame, isMirrored: !(self.back))
                            dispatch_async(dispatch_get_main_queue(), {
                                self.faces[id]!.updateFrame(frame)
                            })
                        } else {
                            if(steady) {
                                let frame = self.transformFacialFeaturePosition(face.bounds.minX, yPosition: face.bounds.minY, width: face.bounds.width, height: face.bounds.height, previewRect: self.cameraPreview.frame, isMirrored: !(self.back))
                                self.faces.updateValue(Face(bounds: frame), forKey: id)
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.view.addSubview(self.faces[id]!.frame)
                                })
                                self.takePicture(id)
                            }
                        }
                    }
                    dispatch_async(dispatch_get_main_queue(), {
                        self.cleanFaceBoxes()
                    })
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    let keys = self.faces.keys
                    for key in keys {
                        self.faces[key]?.frame.outline.removeFromSuperview()
                    }
                    self.faces.removeAll()
                })
            }
        }
        frames += 1
    }
    
    //takes picture
    func takePicture(id: Int) {
        let videoConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        if videoConnection != nil {
            
            // Secure image
            stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                let originalImage = UIImage(data: imageData)
                let cim = CIImage(CGImage: (originalImage?.CGImage)!)
                let imageOptions = [CIDetectorImageOrientation : 6]
                let faces = self.detector!.featuresInImage(cim, options: imageOptions)
                for f in faces {
                    let face = f as! CIFaceFeature

                    if(face.hasLeftEyePosition && face.hasRightEyePosition) {
                                 
                        var image = originalImage!
                        
                        if(face.rightEyePosition != face.leftEyePosition) {
                            //rotate face to horizontal
                            image = self.rotateFace(face, image: image)
                            //UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }

                        //get new face frame
                        if let straightenedFaces = self.detector!.featuresInImage(CIImage(CGImage: (image.CGImage!)), options: imageOptions) as? [CIFaceFeature] {

                            image = self.cropFace(image, rect: self.matchFaceMethod(face.bounds.origin, list: straightenedFaces).bounds)
                            self.callAPI(image, id: id)
                        }
                    }
                }
            }
        }
    }
    
    func matchFaceMethod(origin: CGPoint, list: [CIFaceFeature]) -> CIFaceFeature {
        var closest = 0
        var distance = getDistanceBetweenPoints(origin, two: list[0].bounds.origin)
        for i in 1..<list.count {
            let newDist = getDistanceBetweenPoints(origin, two: list[i].bounds.origin)
            if(newDist < distance) {
                closest = i
                distance = newDist
            }
        }
        return list[closest]
    }
    
    func getDistanceBetweenPoints(one: CGPoint, two: CGPoint) -> CGFloat {
        let xDist = one.x - two.x
        let yDist = one.y - two.y
        return pythagorean(xDist, b: yDist)
    }
    
    func setFacesToNotPresent() {
        let keys = self.faces.keys
        for key in keys {
            self.faces[key]?.present = false
        }
    }
    
    func cleanFaceBoxes() {
        let keys = self.faces.keys
        for key in keys {
            if(!((self.faces[key]?.present)!)) {
                self.faces[key]?.frame.removeFromSuperview()
                if let idx = self.faces.indexForKey(key) {
                    self.faces.removeAtIndex(idx)
                }
            }
        }
    }
    
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
    
    //////////////////////// API /////////////////////
    
    func callAPI(image: UIImage, id: Int) {
        let api = AnalyzeImageAPI(image: image, header: ["Ocp-Apim-Subscription-Key": "8cace64f78f34355b7e2ab22e3b06bed", "Content-Type": "application/octet-stream"])
        api.callAPI() { (rs: String) in
            var noCeleb = true
            
            let dict = (self.convertStringToDictionary(rs)!)
            if let categories = dict["categories"] as? NSArray {
                for i in 0 ..< categories.count {
                    if let details = categories[i]["detail"] as? NSDictionary {
                        if let celebrities = details["celebrities"] as? [NSDictionary] {
                            for celeb in celebrities {
                                noCeleb = false
                                let name = (celeb["name"] as! String)
                                
                                if(!(self.alreadyHasFace(name))) {
                                    self.saveFace(name, image: image)
                                    self.segButton.setTitleColor(UIColor.cyanColor(), forState: .Normal)
                                }
                                
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.removeLastBanner()
                                    var count = 1
                                    for banner in self.banners {
                                        banner.bump(CGFloat(count))
                                        count += 1
                                    }
                                    self.faces[id]!.name = name
                                    self.faces[id]!.image = image
                                    let b = FaceDetectionBanner(celebrity: ["name": name, "image": image])
                                    self.banners.insert(b, atIndex: 0)
                                    self.view.addSubview(b)
                                })
                            }
                        }
                    }
                }
            }
            if(noCeleb) {
                dispatch_async(dispatch_get_main_queue(), {
                    self.removeLastBanner()
                    var count = 1
                    for banner in self.banners {
                        banner.bump(CGFloat(count))
                        count += 1
                    }
                    
                    let b = FaceDetectionBanner()
                    self.banners.insert(b, atIndex: 0)
                    self.view.addSubview(b)
                })
            }
        }
    }
    
    ////////// CROP / ROTATE / TRANSFORM /////////////
    
    func rotateFace(face: CIFaceFeature, image: UIImage) -> UIImage {
        let xDistance = face.leftEyePosition.y - face.rightEyePosition.y
        let yDistance = face.leftEyePosition.x - face.rightEyePosition.x
        let hypotenuse = self.pythagorean(xDistance, b: yDistance)
        
        let rads = asin(yDistance / hypotenuse)
        
        let i = imageRotatedByDegrees(image, rads: rads)
        
        return i
    }
    
    func imageRotatedByDegrees(oldImage: UIImage, rads: CGFloat) -> UIImage {
        //Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRectMake(0, 0, oldImage.size.width, oldImage.size.height))
        let t: CGAffineTransform = CGAffineTransformMakeRotation(rads)
        rotatedViewBox.transform = t
        let rotatedSize: CGSize = rotatedViewBox.frame.size
        //Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap: CGContextRef = UIGraphicsGetCurrentContext()!
        //Move the origin to the middle of the image so we will rotate and scale around the center.
        CGContextTranslateCTM(bitmap, rotatedSize.width / 2, rotatedSize.height / 2)
        //Rotate the image context
        CGContextRotateCTM(bitmap, rads)
        //Now, draw the rotated/scaled image into the context
        CGContextScaleCTM(bitmap, 1.0, -1.0)
        CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.height, oldImage.size.width), oldImage.CGImage!)
        
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return UIImage(CGImage: newImage.CGImage!, scale: oldImage.scale, orientation: oldImage.imageOrientation)
    }
    
    //returns the frame for the face box
    private func transformFacialFeaturePosition(xPosition: CGFloat, yPosition: CGFloat, width: CGFloat, height: CGFloat, previewRect: CGRect, isMirrored: Bool) -> CGRect {
        
        var featureRect = CGRect(origin: CGPoint(x: xPosition, y: yPosition), size: CGSize(width: width, height: height))
        let widthScale = previewRect.size.width / 480.0
        let heightScale = previewRect.size.height / 640.0
        
        let transform = isMirrored ? CGAffineTransformMake(0, heightScale, -widthScale, 0, previewRect.size.width, 0) :
            CGAffineTransformMake(0, heightScale, widthScale, 0, 0, 0)
        
        featureRect = CGRectApplyAffineTransform(featureRect, transform)
        
        featureRect = CGRectOffset(featureRect, previewRect.origin.x, previewRect.origin.y)
        
        return featureRect
    }
    
    func pythagorean(a: CGFloat, b: CGFloat) -> CGFloat {
        return sqrt((a * a) + (b * b))
    }
    
    func cropFace(image: UIImage, rect: CGRect) -> UIImage {
        let transformedRect = CGRect(x: rect.minY, y: rect.minX, width: rect.height, height: rect.width)
        
        let oddRect = CGRect(x: transformedRect.minY, y: image.size.width - transformedRect.minX - transformedRect.width, width: transformedRect.height, height: transformedRect.width)
        
        let cgimge = CGImageCreateWithImageInRect(image.CGImage!, oddRect)
        let im = UIImage(CGImage: cgimge!, scale: image.scale, orientation: image.imageOrientation)
        return im
    }
    
    
    /////////////// HELPER METHODS ///////////////////
    func removeLastBanner() {
        if(banners.count == 3) {
            banners[2].removeFromSuperview()
            banners.removeAtIndex(2)
        }
    }
    
    func alreadyHasFace(name: String) -> Bool {
        for face in detectedFaces {
            if(face.valueForKey("name") as! String == name) {
                return true
            }
        }
        return false
    }


    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showFaces" {
            let controller = segue.destinationViewController as! CRFacesViewController
            controller.faces = self.detectedFaces
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
    
    func showFaces(sender: AnyObject) {
        self.performSegueWithIdentifier("showFaces", sender: nil)
    }
    
}

//////////// CAMERA EXTENSION & CLASSES //////////////////////

// AVCaptureVideoDataOutputSampleBufferDelegate protocol and related methods
extension CRViewController:  AVCaptureVideoDataOutputSampleBufferDelegate{
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

class FaceDetectionBanner: UIView {
    
    var dict = NSDictionary()
    var label = UILabel()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(celebrity: NSDictionary) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let frame = CGRect(x: 0, y: 20, width: UIScreen.mainScreen().bounds.width, height: 26)
        label = UILabel(frame: frame)
        label.text = (celebrity["name"] as! String)
        label.textColor = UIColor.whiteColor()
        label.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.75)
        self.addSubview(label)
    }
    
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let frame = CGRect(x: 0, y: 20, width: UIScreen.mainScreen().bounds.width, height: 26)
        label = UILabel(frame: frame)
        label.text = "Could not get face"
        label.backgroundColor = UIColor(red: 255, green: 0, blue: 0, alpha: 0.75)
        label.textColor = UIColor.whiteColor()
        self.addSubview(label)
    }
    
    func bump(count: CGFloat) {
        UIView.animateWithDuration(0.1, animations: { () -> Void in
            self.label.transform = CGAffineTransformMakeTranslation(0.0, 26.0 * (count))
        })
    }
    
    func remove(count: CGFloat) {
        UIView.animateWithDuration(0.1, animations: { () -> Void in
            self.label.transform = CGAffineTransformMakeTranslation(0.0, 78.0)
        })
    }
}

class FaceRectangle: UIView {
    var outline = UILabel()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let x = frame.minX
        let y = frame.minY
        let height = frame.height
        let width = frame.width
        
        outline.frame = CGRect(x: x, y: y, width: width, height: height)
        outline.layer.borderColor = UIColor.whiteColor().CGColor
        outline.layer.borderWidth = 3.0
        self.addSubview(outline)
    }
}
