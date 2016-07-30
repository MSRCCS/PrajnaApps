//
//  MDLHomeViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/22/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Photos


class MDLHomeViewController: UIViewController {
    
    let locationManager = CLLocationManager()
    var information = [NSDictionary]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.requestWhenInUseAuthorization()
    }
    
    override func didReceiveMemoryWarning() {
        //
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showMap" {
            let controller = segue.destinationViewController as! MDLMapViewController
            controller.information = self.information
        }
    }

}