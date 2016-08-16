//
//  MDLGalleryViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/26/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/* This is a gallery class that displays all photos in the Azure Storage Account
 * This View Controller is obsoleted, it is not in the app */

import Foundation
import UIKit

class MDLGalleryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var cv:UICollectionView!

    var photos = [UIImage]()
    var information = [String]()
    var informationDictionary = [NSDictionary]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        loadPhotos()
        
        let mapButton = UIBarButtonItem(title: "Map", style: .Plain, target: self, action: #selector(self.showMapView(_:)))
        self.navigationItem.rightBarButtonItem = mapButton
    }

    func showMapView(sender: UIBarButtonItem) {
        self.performSegueWithIdentifier("showMapView", sender: nil)
    }
    
    func configureCollectionView() {
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColor = UIColor.whiteColor()
        cv.contentInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cv.reloadData()
    }
    
    func loadPhotos() {
        do {
            let account = try AZSCloudStorageAccount(fromConnectionString:"DefaultEndpointsProtocol=https;AccountName=prajnabot;AccountKey=T5dp2kZO0vMJzlFo54a+ZgELkVinI4HZe5Hl9e6XLIO2Rj7i680cFl7ztHN8uIbiL95Z03DlY+hGUE+Uds2ziw==") //I stored the property in my header file
            
            let blobClient: AZSCloudBlobClient = account.getBlobClient()
            
            let blobContainer: AZSCloudBlobContainer = blobClient.containerReferenceFromName("test-image-blob")
            
            blobContainer.createContainerIfNotExistsWithAccessType(AZSContainerPublicAccessType.Container, requestOptions: nil, operationContext: nil) { (NSError, Bool) -> Void in
                
                if ((NSError) != nil){
                    
                    NSLog("Error in creating container.")
                    
                }
                    
                else {
                    var blobNames = [String]()
                    
                    blobContainer.listBlobsSegmentedWithContinuationToken(AZSContinuationToken.init(), prefix: "", useFlatBlobListing: true, blobListingDetails: AZSBlobListingDetails.All, maxResults: 10, completionHandler: { (_,result: AZSBlobResultSegment?) in
                        for blob in result!.blobs! {
                            if let type = (blob as? AZSCloudBlob)?.properties.contentType {
                                if(type == "JPEG") {
                                    blobNames.append(((blob as? AZSCloudBlob)?.blobName)!)
                                }
                            } else {
                                print("Couldn't get type")
                            }
                        }
                        
                        for name in blobNames {
                            let blob: AZSCloudBlockBlob = blobContainer.blockBlobReferenceFromName(name)
                            blob.downloadToDataWithCompletionHandler({(_, data: NSData?) in
                                if let img = UIImage(data: data!) {
                                    dispatch_async(dispatch_get_main_queue(), {
                                        self.photos.append(img)
                                        self.cv.reloadData()
                                    })
                                }
                            })
                            
                            let stringBlob: AZSCloudAppendBlob = blobContainer.appendBlobReferenceFromName(name + "-m")
                            stringBlob.downloadToTextWithCompletionHandler({(_, str: String?) in
                                self.information.append(str!)
                            self.informationDictionary.append(self.convertStringToDictionary(str!)!)
                            })
                            
                        }
                    })
                }
            }
        } catch {
            print("Could not get account from connection string")
        }
    }
    

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showMapView" {
            let controller = segue.destinationViewController as! MDLMapViewController
            controller.information = self.informationDictionary
            controller.photos = self.photos
        }
    }
    
    override func didReceiveMemoryWarning() {
        //
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        //do something with photo
        
        //launch popover with data
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("galleryCell", forIndexPath: indexPath) as! GalleryCollectionViewCell
        cell.imageView.image = photos[indexPath.row]
        cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit
        print(indexPath.row)
        return cell
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSizeMake(self.view.frame.size.width / 3 - 9, self.view.frame.size.width / 3 - 9)
    }
}

class GalleryCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
}
