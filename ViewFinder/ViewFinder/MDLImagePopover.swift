//
//  MDLImagePopover.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/28/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/* This is the image popover displayed on the map, it will have the image and information about the image on it */

import Foundation
import UIKit

class MDLImagePopover: UIViewController {
    
    @IBOutlet weak var imageView:UIImageView!
    var imageName = String()
    let activityIndicator = UIActivityIndicatorView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        imageView.addSubview(activityIndicator)
        imageView.contentMode = .ScaleAspectFit
        loadPhoto()
    }
    
    override func didReceiveMemoryWarning() {
        //
    }
    
    //downloads the photo
    func loadPhoto() {
        do {
            let account = try AZSCloudStorageAccount(fromConnectionString:"DefaultEndpointsProtocol=https;AccountName=prajnabot;AccountKey=T5dp2kZO0vMJzlFo54a+ZgELkVinI4HZe5Hl9e6XLIO2Rj7i680cFl7ztHN8uIbiL95Z03DlY+hGUE+Uds2ziw==") //I stored the property in my header file
            
            let blobClient: AZSCloudBlobClient = account.getBlobClient()
            
            let blobContainer: AZSCloudBlobContainer = blobClient.containerReferenceFromName("test-image-blob")
            
            blobContainer.createContainerIfNotExistsWithAccessType(AZSContainerPublicAccessType.Container, requestOptions: nil, operationContext: nil) { (NSError, Bool) -> Void in
                
                if ((NSError) != nil){
                    
                    NSLog("Error in creating container.")
                    
                } else {
                    let blob: AZSCloudBlockBlob = blobContainer.blockBlobReferenceFromName(self.imageName)
                    blob.downloadToDataWithCompletionHandler({(_, data: NSData?) in
                        if let img = UIImage(data: data!) {
                            dispatch_async(dispatch_get_main_queue(), {
                                self.imageView.image = img
                                self.activityIndicator.stopAnimating()
                            })
                        }
                    })
                }
            }
        } catch {
            print("Could not get account from connection string")
        }
    }
}