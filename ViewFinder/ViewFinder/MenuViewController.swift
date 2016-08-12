//
//  MenuViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/24/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 * This is the menu view controller. It is what the user sees
 * and changes the state. It sets state variables in a "MenuViewControllerDelegate"
 * These state variables control what api the app calls. For instance - 
 * calling the translate api and which language it translates to
*/

import Foundation
import UIKit

protocol MenuViewControllerDelegate {
    func changeState(state: Int, details: String)
}

class MenuViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var faceButton:UIButton!
    @IBOutlet weak var translateButton: UIButton!
    @IBOutlet weak var prajnaButton: UIButton!
    
    let table = UITableView()
    let cover = UIView()
    let backButton = UIButton()
    let cancelButton = UIButton()
    
    var api = Int()
    var camState = Int()
    var camDetails = String()
    var tableData = Int()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        table.frame = CGRect(x: 0, y: 44, width: 180, height: 450 - 44)
        table.scrollEnabled = true
        table.dataSource = self
        table.delegate = self
        table.reloadData()

        configureActions()
    }
    
    func configureActions() {
        faceButton.tag = 0
        faceButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .TouchUpInside)
        
        translateButton.tag = 1
        translateButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .TouchUpInside)
        
        prajnaButton.tag = 4
        prajnaButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .TouchUpInside)
        
        cover.frame = CGRect(x: 0, y: 0, width: 180, height: 44)
        cover.backgroundColor = UIColor.whiteColor()
        
        cancelButton.frame = CGRect(x: 3 * (180 / 4.0) - 40.0, y: 2.0, width: 80.0, height: 40.0)
        print(cancelButton.frame)
        cancelButton.layer.cornerRadius = 0.25 * cancelButton.bounds.size.width
        cancelButton.setTitle("Cancel", forState: .Normal)
        cancelButton.backgroundColor = UIColor.darkGrayColor()
        cancelButton.addTarget(self, action: #selector(self.cancel(_:)), forControlEvents: .TouchUpInside)
        
        backButton.frame = CGRect(x: (180 / 4.0) - 40.0, y: 2.0, width: 80.0, height: 40.0)
        print(backButton.frame)
        backButton.layer.cornerRadius = 0.25 * cancelButton.bounds.size.width
        backButton.setTitle("Back", forState: .Normal)
        backButton.backgroundColor = UIColor.darkGrayColor()
        backButton.addTarget(self, action: #selector(self.back(_:)), forControlEvents: .TouchUpInside)
    }
    
    func buttonPressed(sender: UIButton) {
        if(sender.tag == 0) {
            passDataBackWards(sender.tag, details: "")
            self.dismissViewControllerAnimated(true, completion: nil)
        } else {
            self.view.addSubview(table)
            self.view.addSubview(cover)
            self.view.addSubview(backButton)
            self.view.addSubview(cancelButton)
            if(sender.tag == 1) {
                self.tableData = 1
                table.reloadData()
            } else if(sender.tag == 4) {
                self.tableData = 4
                table.reloadData()
            }
        }
    }
    
    func cancel(sender: UIButton) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func back(sender: UIButton) {
        cancelButton.removeFromSuperview()
        backButton.removeFromSuperview()
        table.removeFromSuperview()
        cover.removeFromSuperview()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if(tableData == 1) {
            let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "ri")
            cell.textLabel!.text = languages[indexPath.row]["name"]
            return cell
        }
        let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "ri")
        cell.textLabel!.text = prajnaCodes[indexPath.row]["name"]
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if(tableData == 1) {
            passDataBackWards(1, details: languages[indexPath.row]["code"]!)
        } else if(tableData == 4) {
            passDataBackWards(4, details: prajnaCodes[indexPath.row]["code"]!)
        }
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(tableData == 1) {
            return languages.count
        } else {
            return prajnaCodes.count
        }
        
    }
    
    var delegate: MenuViewControllerDelegate?
    
    func passDataBackWards(state: Int, details: String) {
        delegate?.changeState(state, details: details)
    }
    
    func setDetails(camState: Int, camDetails: String) {
        self.camState = camState
        self.camDetails = camDetails
        if(camState == 0) {
            faceButton.setImage(UIImage(named: "FaceSelected.png"), forState: .Normal)
        } else if(camState == 1) {
            translateButton.setImage(UIImage(named: "TranslateSelected.png"), forState: .Normal)
        } else if(camState == 4) {
            prajnaButton.setImage(UIImage(named: "PrajnaSelected.png"), forState: .Normal)
        }
    }
}
