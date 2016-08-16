//
//  TermsViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 8/16/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class TermsViewController: UIViewController {
    
    @IBOutlet weak var terms: UITextView!
    @IBOutlet weak var declineButton: UIBarButtonItem!
    @IBOutlet weak var acceptButton: UIBarButtonItem!
    
    @IBAction func acceptTerms() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "AgreedToTerms")
        performSegueWithIdentifier("acceptedTerms", sender: nil)
    }
    
    @IBAction func declineTerms() {
        let alert = UIAlertController(title: "Dude....", message: "You have to agree to the terms to use the app", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Terms of Use"
        
        terms.text = "Lorem ipsum dolor sit er elit lamet, consectetaur cillium adipisicing pecu, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Nam liber te conscient to factor tum poen legum odioque civiuda."
        terms.editable = false
        terms.userInteractionEnabled = false
        terms.textAlignment = NSTextAlignment.Left
        terms.font = UIFont(name: (terms.font?.fontName)!, size: 18.0)
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
