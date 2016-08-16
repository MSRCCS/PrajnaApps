//
//  MDLMapViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/28/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*This is the view controller for the MyDigialLife Photo Map*/

import Foundation
import UIKit
import CoreLocation
import MapKit

let touchedPinString = "MDLMVCPinTouchedNotification"

class MDLMapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UIPopoverPresentationControllerDelegate {
    
    @IBOutlet weak var map:MKMapView!
    let locationManager = CLLocationManager()
    var photos = [UIImage]()
    var information = [NSDictionary]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if(addLocationManager()) {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.touchedPin(_:)), name: touchedPinString, object: nil)
            
            //set up map
            map.delegate = self
            let location = getCurrentLocation()
            
            // 2
            let span = MKCoordinateSpanMake(0.05, 0.05)
            let region = MKCoordinateRegion(center: location, span: span)
            map.setRegion(region, animated: true)
            map.showsUserLocation = true
            
            addPhotos()
        }
    }
    
    //////////////////// SET UP ///////////////////////
    
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
    
    func addPhotos() {
        var counter = 0
        for photo in information {
            if (photo["latitude"] as! String != "" && photo["longitude"] as! String != "") {
                
                let latitude = Double(photo["latitude"] as! String)
                let longitude = Double(photo["longitude"] as! String)
                
                let pin = CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)
                let annotation = MKPointAnnotation()
                annotation.coordinate = pin
                let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "pin")
                annotation.title = String(counter)
                annotationView.canShowCallout = false
                map.addSubview(annotationView)
                map.addAnnotation(annotation)
                counter += 1
            } else {
                print("NO LOCATION FOR \(photo)")
            }
        }
    }
    
    //////////////////// POPOVER /////////////////////
    
    func adaptivePresentationStyleForPresentationController(
        controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
    func touchedPin(sender: NSNotification) {
        let annotationView = sender.object as! MKAnnotationView
        let num = Int((annotationView.annotation?.title!)!)!
        
        let storyboard = UIStoryboard(name: "MyDigitalLife", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("imagepopover") as! MDLImagePopover
        
        controller.preferredContentSize = CGSizeMake(300, 300)
        
        controller.imageName = (information[num]["imagename"] as! String)
        
        controller.modalPresentationStyle = UIModalPresentationStyle.Popover
        
        let popoverPresentationController = controller.popoverPresentationController
        
        popoverPresentationController!.sourceView = self.view
        popoverPresentationController!.sourceRect = annotationView.frame
        
        popoverPresentationController!.permittedArrowDirections = .Any
        popoverPresentationController!.delegate = self
        
        self.presentViewController(controller, animated: true, completion: nil)
    }
    
    /////////////////// LOCATION ////////////////////
    
    func getCurrentLocation() -> CLLocationCoordinate2D {
        self.locationManager.startUpdatingLocation()
        let latitude = self.locationManager.location!.coordinate.latitude
        let longitude = self.locationManager.location!.coordinate.longitude
        self.locationManager.stopUpdatingLocation()
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func addLocationManager() -> Bool {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            return true
        }
        return false
    }
    
    /////////////////// HELPER //////////////////////
    
    override func didReceiveMemoryWarning() {
    }
    

}

extension MKAnnotationView {
    
    // this is here so it can determine which photo pin is touched
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.canShowCallout = false
        NSNotificationCenter.defaultCenter().postNotificationName(touchedPinString, object: self)
    }
}
