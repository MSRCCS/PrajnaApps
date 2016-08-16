//
//  TensorflowMenu.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/24/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 * This is the menu View Controller for the Tensorflow Version
 * Instead of translation and prajna hub it has Tensorflow and Celebrity Recognition
 */

import Foundation
import UIKit

protocol TensorflowMenuDelegate {
    func changeState(state: Int, details: String)
}

class TensorflowMenu: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var faceButton:UIButton!
//    @IBOutlet weak var translateButton: UIButton!
    @IBOutlet weak var tensorflowButton: UIButton!
    @IBOutlet weak var celebrityButton: UIButton!
    
    let table = UITableView()
    let cover = UIView()
    let backButton = UIButton()
    let cancelButton = UIButton()

    var api = Int()
    var camState = Int()
    var camDetails = String()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        table.frame = CGRect(x: 0, y: 44, width: 180, height: 450 - 44)
        table.dataSource = self
        table.delegate = self
        table.reloadData()

        configureActions()
    }
    
    func configureActions() {
        faceButton.tag = 0
        faceButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .TouchUpInside)
        
//        translateButton.tag = 1
//        translateButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .TouchUpInside)
        
        tensorflowButton.tag = 2
        tensorflowButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .TouchUpInside)
        
        celebrityButton.tag = 3
        celebrityButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .TouchUpInside)
        
        cover.frame = CGRect(x: 0, y: 0, width: 180, height: 44)
        cover.backgroundColor = UIColor.whiteColor()
        
        cancelButton.frame = CGRect(x: 3 * (180 / 4.0) - 40.0, y: 2.0, width: 80.0, height: 40.0)
        cancelButton.layer.cornerRadius = 0.25 * cancelButton.bounds.size.width
        cancelButton.setTitle("Cancel", forState: .Normal)
        cancelButton.backgroundColor = UIColor.darkGrayColor()
        cancelButton.addTarget(self, action: #selector(self.cancel(_:)), forControlEvents: .TouchUpInside)
        
        backButton.frame = CGRect(x: (180 / 4.0) - 40.0, y: 2.0, width: 80.0, height: 40.0)
        backButton.layer.cornerRadius = 0.25 * cancelButton.bounds.size.width
        backButton.setTitle("Back", forState: .Normal)
        backButton.backgroundColor = UIColor.darkGrayColor()
        backButton.addTarget(self, action: #selector(self.back(_:)), forControlEvents: .TouchUpInside)
    }
    
    func buttonPressed(sender: UIButton) {
        if(sender.tag == 1) {
            self.view.addSubview(table)
            self.view.addSubview(cover)
            self.view.addSubview(backButton)
            self.view.addSubview(cancelButton)
        } else {
            passDataBackWards(sender.tag, details: "")
            self.dismissViewControllerAnimated(true, completion: nil)
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
        let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "ri")
        cell.textLabel!.text = languages[indexPath.row]["name"]
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        passDataBackWards(1, details: languages[indexPath.row]["code"]!)
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return languages.count
    }
    
    var delegate: TensorflowMenuDelegate?
    
    func passDataBackWards(state: Int, details: String) {
        delegate?.changeState(state, details: details)
    }
    
    func setDetails(camState: Int, camDetails: String) {
        self.camState = camState
        self.camDetails = camDetails
        if(camState == 0) {
            faceButton.setImage(UIImage(named: "FaceSelected.png"), forState: .Normal)
        } else if(camState == 1) {

        } else if(camState == 2) {
            tensorflowButton.setImage(UIImage(named: "TensorflowSelected.png"), forState: .Normal)
        } else if(camState == 3) {
            celebrityButton.setImage(UIImage(named: "CelebritySelected.jpg"), forState: .Normal)
        }
    }
}
