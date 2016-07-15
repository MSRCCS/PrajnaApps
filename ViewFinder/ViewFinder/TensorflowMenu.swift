//
//  TensorflowMenu.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/24/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 * This is the menu View Controller for the Tensorflow Version
 */

import Foundation
import UIKit

protocol TensorflowMenuDelegate {
    func changeState(state: Int, details: String)
}

class TensorflowMenu: UITableViewController {
    
    @IBOutlet weak var table: UITableView!
    
    let apiNames = ["Facial Recognition", "Translation", "Tensorflow"]
    
    var apis = [[Dictionary<String, String>]]()
    
    let languages = [["name": "Arabic", "code": "ar"], ["name": "Chinese", "code": "zh-CHS"], ["name": "Dutch", "code": "nl"], ["name": "English", "code": "en"], ["name": "French", "code": "fr"], ["name": "German", "code": "de"], ["name": "Hebrew", "code": "he"], ["name": "Hindi", "code": "hi"], ["name": "Indonesian", "code": "id"], ["name": "Italian", "code": "it"], ["name": "Japanese", "code": "ja"], ["name": "Korean", "code": "ko"], ["name": "Portuguese", "code": "pt"], ["name": "Russian", "code": "ru"], ["name": "Spanish", "code": "es"], ["name": "Turkish", "code": "tr"], ["name": "Vietnamese", "code": "vi"]]
    let faces = [["name": "Standard", "code": ":-)"], ["name": "Celebrity", "code": "B-)"]]
    let tensorflow = [["name": "Tensorflow", "code": "tf"]]
    
    var menuState = 0
    var api = Int()
    var camState = Int()
    var camDetails = String()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        apis = [faces, languages, tensorflow]
        
        table.dataSource = self
        table.delegate = self
        
        table.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("menuItem", forIndexPath: indexPath)
        
        if(menuState == 0) {
            cell.textLabel!.text = apiNames[indexPath.row]
            if(indexPath.row == camState) {
                cell.textLabel!.text = cell.textLabel!.text! + " *"
            }
            
        } else {
            let text = apis[camState][indexPath.row]["name"]
            let code = apis[camState][indexPath.row]["code"]
            cell.textLabel!.text = text
            if(camDetails == code) {
                cell.textLabel!.text = text! + " *"
            }
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if(menuState == 0) {
            if(indexPath.row == 2) {
                passDataBackWards(2, details: "TF")
                self.dismissViewControllerAnimated(true, completion: nil)
            } else {
                menuState += 1
                camState = indexPath.row
                table.reloadData()
            }
        } else {
            passDataBackWards(camState, details: apis[camState][indexPath.row]["code"]!)
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(menuState == 0) {
            return apis.count
        } else {
            return apis[camState].count
        }
    }
    
    var delegate: TensorflowMenuDelegate?
    
    func passDataBackWards(state: Int, details: String) {
        delegate?.changeState(state, details: details)
    }
    
    
}