//
//  FacesViewController.swift
//  CropFaceTests
//
//  Created by Jacob Kohn on 8/3/16.
//  Copyright © 2016 Jacob Kohn. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class CRFacesViewController: UITableViewController {
    
    var faces = [NSManagedObject]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Faces"
    }
    
    override func didReceiveMemoryWarning() {

    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return faces.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("faceCell") as! CRFaceTableCell
        let imageData = faces[indexPath.row].valueForKey("image") as! NSData
        cell.imgView.image = UIImage(data: imageData)
        cell.label.text = (faces[indexPath.row].valueForKey("name") as? String)
        cell.label.adjustsFontSizeToFitWidth = true
        cell.button.tag = indexPath.row
        cell.button.addTarget(self, action: #selector(self.showWikipedia(_:)), forControlEvents: .TouchUpInside)
    
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("showFaceDetails", sender: indexPath)
    }
    
    func showWikipedia(sender: UIButton) {
        let name = faces[sender.tag].valueForKey("name") as? String
        let nameArr = name!.characters.split{$0 == " "}.map(String.init)
        var urlStr = nameArr[0]
        for i in 1..<nameArr.count {
            urlStr = urlStr + "_" + nameArr[i]
        }
        
        UIApplication.sharedApplication().openURL(NSURL(string: "http://en.wikipedia.org/wiki/" + urlStr)!)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showFaceDetails" {
            if let ip = sender as? NSIndexPath {
                let controller = segue.destinationViewController as! CRFaceDetailController
                controller.face = self.faces[ip.row]
            }
        }
    }
}

class CRFaceTableCell: UITableViewCell {
    
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
}