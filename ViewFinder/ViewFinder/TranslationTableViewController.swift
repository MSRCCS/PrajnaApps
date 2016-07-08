//
//  TranslationTableViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/5/16.
//  Copyright © 2016 Jacob Kohn. All rights reserved.
//

import Foundation
import UIKit

class TranslationTableViewController: UITableViewController {
    
    @IBOutlet var table: UITableView!
    
    var details = [Dictionary<String, String>()]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        table.delegate = self
        table.dataSource = self
        table.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return details.count - 1
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("translationCell") as! TranslationTableCell
        
        cell.toLabel.text = "To: " + details[indexPath.row + 1]["to"]!
        cell.fromLabel.text = "From: " + details[indexPath.row + 1]["from"]!
        cell.originalLabel.text = details[indexPath.row + 1]["original"]
        cell.translatedLabel.text = details[indexPath.row + 1]["translated"]
        
        return cell
    }
}