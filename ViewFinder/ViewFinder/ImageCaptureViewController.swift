//
//  ImageCaptureViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/20/16.
//  Copyright © 2016 Jacob Kohn. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import CoreImage
import MobileCoreServices


class ImageCaptureViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    
    var toggleButton = UIButton()
    var captureButton = UIButton()
    let doubleTap = UITapGestureRecognizer()
    
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
    
    //Face Detector
    var detector: CIDetector?
    var options: [String : AnyObject]?
    var context: CIContext?
    var hasFace = false
    var callFaceAPI = false
    
    var picker = UIImagePickerController()
    var analyzeUploadedImageView:AnalyzeUploadedImageViewController!
    var closeButton = UIButton()
    
    var currentFrame:CIImage!
    var done = false;
    var hasBack = false;
    var hasFront = false;
    var back = true;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.previewView = UIView(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height));
        self.previewView.contentMode = UIViewContentMode.ScaleAspectFit
        self.view.addSubview(previewView);

        configureTapActions()
        
        setUpDetector()
        
        self.picker.delegate = self
        
        self.setupAVCapture()
    }
    
    func uploadPicture(sender: AnyObject) {
            
            //self.picker.delegate = self
            self.picker.sourceType = UIImagePickerControllerSourceType.SavedPhotosAlbum

            self.presentViewController(self.picker, animated: true, completion: nil)

    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {

        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            picker.dismissViewControllerAnimated(true, completion: nil)
            
            analyzeUploadedImageView = AnalyzeUploadedImageViewController(height: self.view.frame.size.height, width: self.view.frame.size.width, image: image)
            
            self.view.addSubview(analyzeUploadedImageView)
            self.view.addSubview(closeButton)
        }
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController)
    {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func capture(url : NSURL) -> UIImage {
        
        let asset: AVAsset = AVAsset(URL: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset);
        let time = CMTimeMakeWithSeconds(1.0, 1)
        
        var actualTime : CMTime = CMTimeMake(0, 0)
        var error : NSError?
        let myImage: CGImage!
        do {
            myImage = try imageGenerator.copyCGImageAtTime(time, actualTime: &actualTime)
        } catch var error1 as NSError {
            error = error1
            myImage = nil
        }
        
        let testImage = UIImage(CGImage: myImage)
        
        return UIImage(CGImage: myImage, scale: 1.0, orientation: .LeftMirrored)
    }
    
    
    /** This method takes a picture of whatever the camera sees */
    func takePicture(sender: AnyObject) {
        var videoConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        if videoConnection != nil {
            
            // Secure image
            stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                var imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                
                var image = UIImage(data: imageData)
                // The above ^^ variable image is the captured image from the camera
                
                let bundle = NSBundle.mainBundle()
                
                let satyaImage = bundle.pathForResource("Satya.jpg", ofType: nil)

                //image = UIImage(contentsOfFile: satyaImage!)
                
                
                //UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)

                //if(self.hasFace) { self.callFaceAPI = true }
                
                //////////////////// AnalyzeImage API ///////////////////
                
                self.analyzeImage(image!)

                ///////////////////////////////
                

                let height = image!.size.height
                let width = image!.size.width

                let resizedHeight = self.view.frame.size.height * (self.view.frame.size.width / width)
                
                self.imageView.image = image!
                self.imageView.frame = CGRect(x:0, y:0, width:self.view.frame.size.width, height: resizedHeight)
                self.view.addSubview(self.imageView)
                
                let dismissButtonHeight = ((self.view.frame.size.height - resizedHeight) / 2)
                
                self.dismissButton.frame = CGRect(x: 0,y: self.view.frame.size.height - dismissButtonHeight, width: self.view.frame.size.width, height: dismissButtonHeight)
                self.view.addSubview(self.dismissButton)
                self.captionLabel.text = "Generating Caption..."
                self.captionLabel.frame = CGRect(x: 0, y: self.view.frame.size.height - (2 * dismissButtonHeight), width: self.view.frame.size.width, height: dismissButtonHeight)
                self.view.addSubview(self.captionLabel)
            }
        }
    }
    
    func analyzeImage(image: UIImage) {
        var responseString = "" as NSString
        
        let request = NSMutableURLRequest(URL: NSURL(string: "https://api.projectoxford.ai/vision/v1.0/analyze?visualFeatures=Faces,Description,Categories&details=Celebrities")!)
        request.HTTPMethod = "POST"
        
        var testUrl = false
        
        if(testUrl) {
            request.allHTTPHeaderFields = ["Ocp-Apim-Subscription-Key": "dca2b686d07a4e18ba81f5731053dbab", "Content-Type": "application/json"]
            do {
                let dic = ["url": "http://ir0.mobify.com/project-oss-mightandmischief-com/1080/http://mightandmischief.com/wp-content/assets/img/1402/weekly-satya.jpg"]
                let jsonData = try NSJSONSerialization.dataWithJSONObject(dic, options: .PrettyPrinted)
                request.HTTPBody = jsonData
            } catch {
                
            }
        } else {
            request.allHTTPHeaderFields = ["Ocp-Apim-Subscription-Key": "dca2b686d07a4e18ba81f5731053dbab", "Content-Type": "application/octet-stream"]
            request.HTTPBody = UIImagePNGRepresentation(image)
        }
        
        
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
                self.displayAnswers(responseString as! String)
                
            }
            
        }
        task.resume()
    }

    
    func setUpDetector() {
        context = CIContext()
        options = [String : AnyObject]()
        options![CIDetectorAccuracy] = CIDetectorAccuracyLow
        
        detector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: options)
    }
    
    func determineIfFace(image: UIImage) {
        print(image.CIImage)
        let imageOptions = [CIDetectorImageOrientation : 6]
        print(detector!.featuresInImage(image.CIImage!, options: imageOptions))
    }
    
    func getFacialFeatures(image: CIImage) -> [CIFeature] {
        let imageOptions = [CIDetectorImageOrientation : 6]
        return detector!.featuresInImage(image, options: imageOptions)
    }
    
    
    func drawFaceRectangle(x: Int, y: Int, height: Int, width: Int, caption: String) {
        
        let resizedHeight = self.view.frame.size.height * (self.view.frame.size.width / 480.0)
        
        let newX = Int(self.view.frame.size.width * (CGFloat(x) / 480.0))
        let newY = Int(resizedHeight * (CGFloat(y) / 640.0))
        let newHeight = Int(resizedHeight * (CGFloat(height) / 640.0))
        let newWidth = Int(self.view.frame.size.width * (CGFloat(width) / 480.0))
        
        let faceBox = FaceDetectionBox(x: newX, y: newY, height: newHeight, width: newWidth, caption: caption)
        self.view.addSubview(faceBox)
        faces.append(faceBox)
        print("Drew FaceBox at: " + String(newX) + ", " + String(newY) + " with dimensions " + String(newHeight) + "x" + String(newWidth))
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
    }
    
    //adds the double tap to the view
    func configureTapActions() {
        doubleTap.numberOfTapsRequired = 2
        doubleTap.addTarget(self, action: #selector(ImageCaptureViewController.toggle(_:)))
    }
    
    //adds attributes to the buttons and adds some of them to the view
    func addButtons() {
        toggleButton.frame = CGRectMake(0, 20, 45, 25)
        toggleButton.addTarget(self, action: #selector(ImageCaptureViewController.uploadPicture(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        let flipImage = UIImage(named:"FlipCameraButton.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        toggleButton.tintColor = UIColor.whiteColor()
        toggleButton.setImage(flipImage, forState: .Normal)
        //toggleButton.backgroundColor = UIColor.blackColor()
        self.view.addSubview(toggleButton)
        
        captureButton.frame = CGRectMake(self.view.frame.width / 2 - 45, self.view.frame.height - 110, 90, 90)
        let captureImage = UIImage(named: "CaptureButtonPNG.png")!
        captureButton.setImage(captureImage, forState: .Normal)
        captureButton.addTarget(self, action: #selector(ImageCaptureViewController.takePicture(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(captureButton)
        
        dismissButton.setTitle("Dismiss", forState: .Normal)
        dismissButton.backgroundColor = UIColor.blackColor()
        dismissButton.addTarget(self, action: #selector(ImageCaptureViewController.dismissCapturedImage(_:)), forControlEvents: .TouchUpInside)
        
        captionLabel.backgroundColor = UIColor.darkGrayColor()
        captionLabel.textColor = UIColor.whiteColor()
        captionLabel.textAlignment = NSTextAlignment.Center
        
        closeButton.frame = CGRectMake(0.0, self.view.frame.size.height - 44, self.view.frame.size.width, 44)
        closeButton.addTarget(self, action: #selector(ImageCaptureViewController.dismissUploadImageVC(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        closeButton.backgroundColor = UIColor.blackColor()
        closeButton.setTitle("Dismiss", forState: .Normal)
    }
    
    func dismissUploadImageVC(sender: AnyObject) {
        analyzeUploadedImageView.removeFromSuperview()
        closeButton.removeFromSuperview()
    }
    
    //toggles between the front and back cameras
    func toggle(sender: AnyObject) {
        
        for ii in session.inputs {
            session.removeInput(ii as! AVCaptureInput)
        }
        
        if(back) {
            if(hasFront) {
                var error: NSError?
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
                var error: NSError?
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
    
    //Touch to focus
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = touches.first!
        super.touchesBegan(touches, withEvent: event)
        
        let touchedPoint = touch.locationInView(cameraPreview)
        
        
        let newPoint = CGPoint(x: 480 * (touchedPoint.x / self.view.frame.size.width), y: 640 * (touchedPoint.y / self.view.frame.size.height))
        
        self.focusAtPoint(newPoint)
    }
}


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
            //break;
        }
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        let image = getImageFromBuffer(sampleBuffer)
        
        let features = self.getFacialFeatures(image)
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        
        let cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription!, false)
        
        if(features.isEmpty) {
            hasFace = false
        } else {
            hasFace = true
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
        session.stopRunning()
        done = false;
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