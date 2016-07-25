//
//  MDLCameraViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/22/16.
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
import CoreLocation



class MDLCameraViewController: UIViewController, CLLocationManagerDelegate {
    
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
    
    let locationManager = CLLocationManager()
    let latLabel = UILabel()
    let longLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let height = ((UIScreen.mainScreen().bounds.size.width + 30) * 640.0) / 480.0
        
        self.previewView = UIView(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, height));
        self.previewView.contentMode = UIViewContentMode.ScaleAspectFit
        self.view.addSubview(previewView);
        
        configureTapActions()
        
        self.setupAVCapture()
        
        addLocationManager()
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
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
        doubleTap.addTarget(self, action: #selector(MDLCameraViewController.toggle(_:)))
    }

    func addLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
    }
    
    //adds attributes to the buttons and adds some of them to the view
    func addButtons() {
        
        let cover = UIView(frame: CGRect(x: 0, y: previewView.bounds.maxY, width: self.view.frame.size.width, height: self.view.frame.size.height - previewView.bounds.height))
        cover.backgroundColor = UIColor.blackColor()
        self.view.addSubview(cover)
        
        //sets up the toggle button
        toggleButton.frame = CGRectMake(0, 20, 50, 40)
        toggleButton.addTarget(self, action: #selector(MDLCameraViewController.toggle(_:)), forControlEvents: UIControlEvents.TouchUpInside)
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
        captureButton.addTarget(self, action: #selector(MDLCameraViewController.takePicture(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(captureButton)

        let cancelButton = UIButton(frame: CGRect(x: 15, y: self.view.frame.size.height - 60, width: 60, height: 44))
        cancelButton.setTitle("Cancel", forState: .Normal)
        cancelButton.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        cancelButton.addTarget(self, action: #selector(self.returnHome(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(cancelButton)
        
        latLabel.frame = CGRect(x: self.view.frame.size.width - 120, y: self.view.frame.size.height - 90, width: 120, height: 40)
        latLabel.text = "Latitude"
        latLabel.textColor = UIColor.whiteColor()
        latLabel.adjustsFontSizeToFitWidth = true
        self.view.addSubview(latLabel)
        
        
        longLabel.frame = CGRect(x: self.view.frame.size.width - 120, y: self.view.frame.size.height - 45, width: 120, height: 40)
        longLabel.text = "Longitude"
        longLabel.textColor = UIColor.whiteColor()
        longLabel.adjustsFontSizeToFitWidth = true
        self.view.addSubview(longLabel)
    }

    
    /////////////////// TAKE PICTURE ////////////////////
    
    /*
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

                //send to server
                
            
                
                self.locationManager.startUpdatingLocation()
                self.latLabel.text! = "\(self.locationManager.location!.coordinate.latitude)"
                self.longLabel.text! = "\(self.locationManager.location!.coordinate.longitude)"
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
    
    func uploadOneImage(image: UIImage) {
        do {
            let account = try AZSCloudStorageAccount(fromConnectionString:"DefaultEndpointsProtocol=https;AccountName=TODO;AccountKey=TODO") //I stored the property in my header file
            
            let blobClient: AZSCloudBlobClient = account.getBlobClient()
            
            let blobContainer: AZSCloudBlobContainer = blobClient.containerReferenceFromName("test-image-blob")
            
            blobContainer.createContainerIfNotExistsWithAccessType(AZSContainerPublicAccessType.Container, requestOptions: nil, operationContext: nil) { (NSError, Bool) -> Void in
                
                if ((NSError) != nil){
                    
                    NSLog("Error in creating container.")
                    
                }
                    
                else {
                    let imageName = CFUUIDCreateString(nil, CFUUIDCreate(nil))
                    let blob: AZSCloudBlockBlob = blobContainer.blockBlobReferenceFromName(imageName as String) //If you want a random name, I used let imageName = CFUUIDCreateString(nil, CFUUIDCreate(nil))
                    
                    let imageData = UIImagePNGRepresentation(image)
                    
                    blob.uploadFromData(imageData!, completionHandler: {(NSError) -> Void in
                        
                        NSLog("Ok, uploaded!")
                        
                    })
                }
            }
        } catch {
            print("Could not get account from connection string")
        }
    }
    
    func save(sender: UIButton) {
        UIImageWriteToSavedPhotosAlbum(currentImage, nil, nil, nil)
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
    
    func returnHome(sender: UIButton) {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
}


//////////// CAMERA EXTENSION //////////////////////

// AVCaptureVideoDataOutputSampleBufferDelegate protocol and related methods
extension MDLCameraViewController:  AVCaptureVideoDataOutputSampleBufferDelegate{
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
            previewLayer.bounds = previewView.bounds
            previewLayer.position = CGPointMake(previewView.bounds.midX, previewView.bounds.midY)
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            let height = (UIScreen.mainScreen().bounds.size.width * 640.0) / 480.0
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