//
//  CRSplashScreen.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 8/4/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import CoreData

class CRSplashScreen: UIViewController {
    
    var detectedFaces = [NSManagedObject]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadFaces()
    }
    
    override func didReceiveMemoryWarning() {
        //
    }
    
    func loadFaces() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedContext = appDelegate.managedObjectContext
        let fetchRequest = NSFetchRequest(entityName: "Face")
        do {
            let results =
                try managedContext.executeFetchRequest(fetchRequest)
            detectedFaces = results as! [NSManagedObject]
            dispatch_async(dispatch_get_main_queue(), {
                self.performSegueWithIdentifier("doneLoading", sender: nil)
            })
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "doneLoading" {
            let navController = segue.destinationViewController as! UINavigationController
            let controller = navController.viewControllers.first as! CRViewController
            controller.detectedFaces = self.detectedFaces
        }
    }
}