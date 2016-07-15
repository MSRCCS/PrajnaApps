//
//  TranslationDetailViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/5/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class TranslationDetailViewController: UIViewController {
    
    var to = String()
    var from = String()
    var original = String()
    var translated = String()
    
    @IBOutlet weak var fromLabel: UILabel!
    @IBOutlet weak var originalTextLabel: UILabel!
    @IBOutlet weak var toLabel: UILabel!
    @IBOutlet weak var translatedTextLabel: UILabel!
    
    let languages = [["name": "Arabic", "code": "ar"], ["name": "Chinese", "code": "zh-CHS"], ["name": "Dutch", "code": "nl"], ["name": "English", "code": "en"], ["name": "French", "code": "fr"], ["name": "German", "code": "de"], ["name": "Hebrew", "code": "he"], ["name": "Hindi", "code": "hi"], ["name": "Indonesian", "code": "id"], ["name": "Italian", "code": "it"], ["name": "Japanese", "code": "ja"], ["name": "Korean", "code": "ko"], ["name": "Portuguese", "code": "pt"], ["name": "Russian", "code": "ru"], ["name": "Spanish", "code": "es"], ["name": "Turkish", "code": "tr"], ["name": "Vietnamese", "code": "vi"]]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for language in languages {
            if (language["code"] == from) {
                from = language["name"]!
            }
            if(language["code"] == to) {
                to = language["name"]!
            }
        }
        
        self.fromLabel.text = "From: " + from
        self.originalTextLabel.text = original
        self.toLabel.text = "To: " + to
        self.translatedTextLabel.text = translated
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func setDetails(dict: Dictionary<String, AnyObject>) {
        self.fromLabel.text = (dict["from"] as! String)
        self.originalTextLabel.text = (dict["original"] as! String)
        self.toLabel.text = (dict["to"] as! String)
        self.translatedTextLabel.text = (dict["translated"] as! String)
    }
}


