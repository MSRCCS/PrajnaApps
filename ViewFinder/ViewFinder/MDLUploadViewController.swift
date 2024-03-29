//
//  MDLUploadViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/25/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit
import Photos

class MDLUploadViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    @IBOutlet weak var cv: UICollectionView!
    
    var metadata = [NSDictionary]()
    var photos = [UIImage]()
    var shouldUpload = [Bool]()
    var activityIndicator = UIActivityIndicatorView()
    let caption = UILabel()
    let cover = UIView()
    let uploadingAlert = UIAlertController(title: "Uploading", message: "Hang on while we upload your images", preferredStyle: .Alert)
    
    //Face Detector
    var detector: CIDetector?
    var options: [String : AnyObject]?
    var context: CIContext?
    
    //Text Detector
    var textDetector: CIDetector?
    var textDetectorOptions: [String : AnyObject]?
    var textContext: CIContext?
    var translating = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let uploadButton = UIBarButtonItem(title: "Upload", style: .Plain, target: self, action: #selector(self.upload(_:)))
        self.navigationItem.rightBarButtonItem = uploadButton
        
        cover.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        cover.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(cover)
        
        activityIndicator.activityIndicatorViewStyle = .Gray
        activityIndicator.center = cover.center
        activityIndicator.startAnimating()
        activityIndicator.hidden = false
        cover.addSubview(activityIndicator)
        
        caption.frame = CGRect(x: self.view.frame.size.width / 2 - 70, y: self.view.frame.size.height / 2 - 50, width: 140, height: 40)
        caption.text = "Loading Photos:"
        caption.textAlignment = .Center
        cover.addSubview(caption)
        
        configureCollectionView()
        
        setUpFaceDetector()
        setUpTextDetector()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        loadPhotos()
    }
    
    
    /////////////////// UPLOADING ////////////////////
    
    
    //uploads all the selected images
    func upload(sender: AnyObject) {
        
        self.presentViewController(uploadingAlert, animated: true, completion: nil)
        
        var lastUpload = 0
        for b in 0..<shouldUpload.count {
            if(shouldUpload[b]) {
                lastUpload = b
            }
        }
        
        for i in 0 ..< shouldUpload.count {
            if(shouldUpload[i]) {
                uploadOneImage(photos[i], index: i, lastImage: lastUpload)
            }
        }
        
    }
    
    //Uploads one image and adds in some metadata
    func uploadOneImage(image: UIImage, index: Int, lastImage: Int) {
        do {
            let account = try AZSCloudStorageAccount(fromConnectionString:"DefaultEndpointsProtocol=https;AccountName=prajnabot;AccountKey=T5dp2kZO0vMJzlFo54a+ZgELkVinI4HZe5Hl9e6XLIO2Rj7i680cFl7ztHN8uIbiL95Z03DlY+hGUE+Uds2ziw==") //I stored the property in my header file
            
            let blobClient: AZSCloudBlobClient = account.getBlobClient()
            
            let blobContainer: AZSCloudBlobContainer = blobClient.containerReferenceFromName("test-image-blob")
            
            blobContainer.createContainerIfNotExistsWithAccessType(AZSContainerPublicAccessType.Container, requestOptions: nil, operationContext: nil) { (NSError, Bool) -> Void in
                
                if ((NSError) != nil){
                    
                    NSLog("Error in creating container.")
                    
                }
                    
                else {
                    let imageName = CFUUIDCreateString(nil, CFUUIDCreate(nil))

                    let blob:AZSCloudBlockBlob = blobContainer.blockBlobReferenceFromName(imageName as String)
                    blob.properties.contentType == "JPEG"
                    let imageData = UIImageJPEGRepresentation(image, 1.0)

                    blob.uploadFromData(imageData!, completionHandler: {(NSError) -> Void in
                        let cell = self.cv.cellForItemAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as! UploadCollectionViewCell
                        cell.selectedFrame.hidden = true
                        cell.selectedFramePresent = false
                        self.shouldUpload[index] = false
                        if(index == lastImage) {
                            self.uploadingAlert.dismissViewControllerAnimated(true, completion: nil)
                        }
                    })
                    
                    //safely unwrap just to be safe
                    var latitude: String! = ""
                    if (self.metadata[index]["latitude"] as? String) != nil {
                        latitude = self.metadata[index]["latitude"] as! String
                    }
                    var longitude: String! = ""
                    if (self.metadata[index]["longitude"] as? String) != nil {
                        longitude = self.metadata[index]["longitude"] as! String
                    }
                    var date: String! = ""
                    if (self.metadata[index]["date"] as? String) != nil {
                        date = self.metadata[index]["date"] as! String
                    }
                    print("LATITUDE \(latitude). LONGITUDE \(longitude)")
                    let jsonObject: [String: AnyObject] = [
                        "latitude": latitude,
                        "longitude": longitude,
                        "faces": self.getFacialFeatures(CIImage(CGImage: image.CGImage!)),
                        "text": self.getTextFeatures(CIImage(CGImage: image.CGImage!)),
                        "date": date,
                        "imagename": imageName]
                    print(jsonObject)
                    do {
                        let obj = try NSJSONSerialization.dataWithJSONObject(jsonObject, options: NSJSONWritingOptions.PrettyPrinted)
                        let jsonStream = NSInputStream(data: obj)
                        let jsonBlob: AZSCloudAppendBlob = blobContainer.appendBlobReferenceFromName((imageName as String) + "-m")
                        jsonBlob.properties.contentType = "STRING"
                        jsonBlob.uploadFromStream(jsonStream, createNew: true, completionHandler: { Void in
                            
                        })
                    }
                    catch {
                        print("UH OH")
                    }
                }
            }
        } catch {
            print("Could not get account from connection string")
        }
    }
    
    func loadPhotos() {

        let requestOptions = PHImageRequestOptions()
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.Exact
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.FastFormat
        requestOptions.synchronous = true
        requestOptions.networkAccessAllowed = false
        let result: PHFetchResult = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: nil)


        var maxPhotos = 40
        if(result.count < maxPhotos) {
            maxPhotos = result.count
        }

        for i in (result.count - maxPhotos ..< result.count).reverse() {
            PHImageManager.defaultManager().requestImageForAsset(result[i] as! PHAsset, targetSize: PHImageManagerMaximumSize, contentMode: PHImageContentMode.Default, options: requestOptions, resultHandler: { image, info in
                if let img = image {
                    
                    let asset = result[i] as! PHAsset
                    var latitude: String! = ""
                    if((asset.location?.coordinate.latitude) != nil) {
                        latitude = String(asset.location!.coordinate.latitude)
                    }
                    var longitude: String! = ""
                    if((asset.location?.coordinate.longitude) != nil) {
                        longitude = String(asset.location!.coordinate.longitude)
                    }

                    var date: String! = ""
                    if(asset.creationDate != nil) {
                        date = String(asset.creationDate!)
                    }
                    self.metadata.append(["latitude": latitude, "longitude": longitude, "date": date])
                    self.photos.append(img)
                    self.shouldUpload.append(false)
                }
            })
        }
        
        
        cover.removeFromSuperview()
        cv.reloadData()
    }
    
    ////////////////////// Collection View ///////////////////////////////
    
    func configureCollectionView() {
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColor = UIColor.whiteColor()
        cv.contentInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cv.reloadData()
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! UploadCollectionViewCell

        cell.selectedFrame.hidden.flip()
        cell.selectedFramePresent.flip()
        shouldUpload[indexPath.row].flip()
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("uploadCell", forIndexPath: indexPath) as! UploadCollectionViewCell

        cell.imageView.image = photos[indexPath.row]
        cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit
        cell.selectedFrame = SelectedFrame(frame: cell.frame)
        
        if(shouldUpload[indexPath.row]) {
            cell.selectedFrame.hidden = false
        } else {
            cell.selectedFrame.hidden = true
        }
        
        cell.addSubview(cell.selectedFrame)
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        cell.backgroundColor = UIColor.whiteColor()
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("uploadCell", forIndexPath: indexPath) as! UploadCollectionViewCell
        
        if(cell.selectedFramePresent) {
            cell.selectedFrame.hidden = true
            cell.selectedFramePresent.flip()
        }
    }
    
    func collectionView(collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSizeMake(self.view.frame.size.width / 3 - 1, self.view.frame.size.width / 3 - 1)
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    ///////////////////// Detectors ////////////////////////////
    
    //sets up the detector to track faces
    func setUpFaceDetector() {
        context = CIContext()
        options = [String : AnyObject]()
        options![CIDetectorAccuracy] = CIDetectorAccuracyLow
        
        detector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: options)
    }

    func getFacialFeatures(image: CIImage) -> Bool {
        let imageOptions = [CIDetectorImageOrientation : 6]
        if(detector!.featuresInImage(image, options: imageOptions).count > 0) {
            return true
        }
        return false
    }
    
    func setUpTextDetector() {
        textDetector = CIDetector(ofType: CIDetectorTypeText, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
    }
    
    func getTextFeatures(image: CIImage) -> Bool {
        let imageOptions = [CIDetectorImageOrientation : 6]
        if(textDetector!.featuresInImage(image, options: imageOptions).count > 0) {
            return true
        }
        return false
    }
    
    ///////////////// NEEDED //////////////////////
    
    override func didReceiveMemoryWarning() {
        //
    }
}

class UploadCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    var selectedFrame: SelectedFrame!
    var selectedFramePresent = false
}

class SelectedFrame: UIView {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        let blue = UIColor(red: 0.2, green: 1.0, blue: 1.0, alpha: 1.0)
        
        let topBorder = UIView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: 5))
        let leftBorder = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: frame.size.height))
        let rightBorder = UIView(frame: CGRect(x: frame.size.width - 5, y: 0, width: 5, height: frame.size.height))
        let bottomBorder = UIView(frame: CGRect(x: 0, y: frame.size.height - 5, width: frame.size.width, height: 5))
        let checkButton = UILabel(frame: CGRect(x: frame.size.width - 20, y: 0, width: 20, height: 20))
        topBorder.backgroundColor = blue
        leftBorder.backgroundColor = blue
        rightBorder.backgroundColor = blue
        bottomBorder.backgroundColor = blue
        checkButton.backgroundColor = blue
        checkButton.text = "✅"
        checkButton.textAlignment = .Center
        checkButton.font = UIFont(name: (checkButton.font?.fontName)!, size: 12.0)
        self.addSubview(topBorder)
        self.addSubview(leftBorder)
        self.addSubview(rightBorder)
        self.addSubview(bottomBorder)
        self.addSubview(checkButton)
    }
}

extension Bool {
    mutating func flip() {
        if(self) {
            self = false
        } else {
            self = true
        }
    }
}