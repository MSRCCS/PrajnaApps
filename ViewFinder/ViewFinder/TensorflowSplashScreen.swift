//
//  TensorflowSplashScreen.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 8/16/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import CoreData

class TensorflowSplashScreen: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadFaces()
        
        //call api to get prajna codes
        
        if(!NSUserDefaults.standardUserDefaults().boolForKey("AgreedToTerms")) {
            dispatch_async(dispatch_get_main_queue(), {
                self.performSegueWithIdentifier("showTerms", sender: nil)
            })
        } else {
            dispatch_async(dispatch_get_main_queue(), {
                self.performSegueWithIdentifier("previouslyAgreed", sender: nil)
            })
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}