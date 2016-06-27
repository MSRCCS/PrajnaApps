//
//  MenuViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/24/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

protocol MenuViewControllerDelegate {
    func changeLanguage(language: String)
}

class MenuViewController: UITableViewController {
    
    @IBOutlet weak var table: UITableView!
    
    var apis = [String]()
    
    var current = String()
    
    let languages = [["language": "Arabic", "code": "ar"], ["language": "Chinese", "code": "zh-CHS"], ["language": "English", "code": "en"], ["language": "French", "code": "fr"], ["language": "German", "code": "de"], ["language": "Hebrew", "code": "he"], ["language": "Italian", "code": "it"], ["language": "Japanese", "code": "ja"], ["language": "Korean", "code": "ko"], ["language": "Portuguese", "code": "pt"], ["language": "Russian", "code": "ru"], ["language": "Spanish", "code": "es"], ["language": "Turkish", "code": "tr"]]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        table.dataSource = self
        table.delegate = self
        
        table.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCellWithIdentifier("menuItem", forIndexPath: indexPath)
        
        if(languages[indexPath.row]["code"] == current) {
            cell.textLabel!.text = languages[indexPath.row]["language"]! + " *"
        } else {
            cell.textLabel!.text = languages[indexPath.row]["language"]!
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        passDataBackWards(languages[indexPath.row]["code"]!)
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return languages.count
    }
    
    var delegate: MenuViewControllerDelegate?
    
    func passDataBackWards(language: String) {
        delegate?.changeLanguage(language)
    }
    
    
}