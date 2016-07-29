//
//  MDLSplashScreen.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/29/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class MDLSplashScreen: UIViewController {
    
    var information = [NSDictionary]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadPhotos({ (didFinish: Bool) in
            self.performSegueWithIdentifier("doneLoading", sender: nil)
        })
        
    }
    
    func loadPhotos(completionHandler: (didFinish: Bool) -> ()) {
        do {
            let account = try AZSCloudStorageAccount(fromConnectionString:"DefaultEndpointsProtocol=https;AccountName=prajnabot;AccountKey=T5dp2kZO0vMJzlFo54a+ZgELkVinI4HZe5Hl9e6XLIO2Rj7i680cFl7ztHN8uIbiL95Z03DlY+hGUE+Uds2ziw==") //I stored the property in my header file
            
            let blobClient: AZSCloudBlobClient = account.getBlobClient()
            
            let blobContainer: AZSCloudBlobContainer = blobClient.containerReferenceFromName("test-image-blob")
            
            blobContainer.createContainerIfNotExistsWithAccessType(AZSContainerPublicAccessType.Container, requestOptions: nil, operationContext: nil) { (NSError, Bool) -> Void in
                
                if ((NSError) != nil){
                    
                    NSLog("Error in creating container.")
                    
                } else {
                    var blobNames = [String]()
                    
                    blobContainer.listBlobsSegmentedWithContinuationToken(AZSContinuationToken.init(), prefix: "", useFlatBlobListing: true, blobListingDetails: AZSBlobListingDetails.All, maxResults: 50, completionHandler: { (_,result: AZSBlobResultSegment?) in
                        for blob in result!.blobs! {
                            if let type = (blob as? AZSCloudBlob)?.properties.contentType {
                                if(type == "STRING") {
                                    blobNames.append(((blob as? AZSCloudBlob)?.blobName)!)
                                    print(((blob as? AZSCloudBlob)?.blobName)!)
                                }
                            } else {
                                print("Couldn't get type")
                            }
                        }
                        
                        var counter = 0
                        for name in blobNames {
                            
                            let stringBlob: AZSCloudAppendBlob = blobContainer.appendBlobReferenceFromName(name)
                            stringBlob.downloadToTextWithCompletionHandler({(_, str: String?) in
                                self.information.append(self.convertStringToDictionary(str!)!)
                                counter += 1
                                if(counter == blobNames.count) {
                                    completionHandler(didFinish: true)
                                }
                            })
                        }
                    })
                }
            }
        } catch {
            completionHandler(didFinish: false)
            print("Could not get account from connection string")
        }
    }
    
    func convertStringToDictionary(text: String) -> [String:AnyObject]? {
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers) as? [String:AnyObject]
                return json
            } catch {
                print("Something went wrong")
            }
        }
        return nil
    }
    
    override func didReceiveMemoryWarning() {
        //
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "doneLoading" {
            let controller = segue.destinationViewController as! UINavigationController
            let homeVC = controller.topViewController as! MDLHomeViewController
            homeVC.information = self.information
            //controller.information = self.information
        }
    }
    
}