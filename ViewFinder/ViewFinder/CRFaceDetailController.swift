//
//  CRFaceDetailController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 8/5/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class CRFaceDetailController: UIViewController, UITextViewDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var birthdayLabel: UILabel!
    @IBOutlet weak var occupationLabel: UILabel!
    @IBOutlet weak var bio: UITextView!
    
    var face: NSManagedObject!
    var wikipedia: NSURL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getWikiLink()
        bio.delegate = self
        
        self.title = "Info"
        self.nameLabel.adjustsFontSizeToFitWidth = true
        self.birthdayLabel.adjustsFontSizeToFitWidth = true
        self.occupationLabel.adjustsFontSizeToFitWidth = true
        
        self.imageView.image = UIImage(data: face.valueForKey("image") as! NSData)
        self.nameLabel.text = (face.valueForKey("name") as! String)
        //self.bio.font = UIFont(name: (self.bio.font?.fontName)!, size: 15.0)
        let call = KnowledgeAPI(name: face.valueForKey("name") as! String)
        call.callAPI({ (rs: String) in
            self.parseRS(rs)
        })
        
        
    }
    
    func parseRS(rs: String) {
        let dict = convertStringToDictionary(rs)
        if let d = dict!["entities"]!["value"]!![0]!["description"] {
            let description = d as! String
            //let attributedText = NSAttributedString(string: description, attributes: nil)
            
            let attributes = [NSForegroundColorAttributeName: UIColor.blueColor(), NSLinkAttributeName: wikipedia, NSFontAttributeName: UIFont(name: "Helvetica", size: 15.0)!]
            let normAttributes = [NSFontAttributeName: UIFont(name: "Helvetica", size: 15.0)!]
            let attrString = NSMutableAttributedString(string: description, attributes: normAttributes)
            let appendString = NSMutableAttributedString(string: "More->", attributes: attributes)
            self.bio.linkTextAttributes = attributes
            attrString.appendAttributedString(appendString)
            self.bio.attributedText = attrString
        }
        //get birthday and occupation
        var birthday = ""
        var occupation = ""
        if let info = dict!["entities"]!["value"]!![0]!["entityPresentationInfo"] {
            if let entityDisplayHint = info!["entityTypeDisplayHint"] {
                occupation = (entityDisplayHint as! String)
            }
            if let facts = info!["formattedFacts"] as? [NSDictionary] {
                for fact in facts {
                    if(fact["label"] as! String == "Born") {
                        if let date = (fact["items"] as! NSArray)[0]["text"] {
                            birthday = date as! String
                        }
                    }
                }
            }
            if let related = info!["related"] as? NSArray {
                for r in related {
                    if(r["id"] as! String == "PeopleAlsoSearchFor") {
                        if let ppl = r["relationships"] as? NSArray {
                            for person in ppl {
                                print(person["relatedThing"]!!["name"])
                            }
                        }
                    }
                }
            }
        }
        self.birthdayLabel.text = "Born: \(birthday)"
        self.occupationLabel.text = occupation
        
        //get websites
        if let arr = dict!["webPages"]!["value"] as? NSArray {
            for page in arr {
                print("NAME: \(page["name"]). URL \(page["url"])")
            }
        }
    }
    
    func textView(textView: UITextView, shouldInteractWithURL URL: NSURL, inRange characterRange: NSRange) -> Bool {
        return true
    }
    
    func textView(textView: UITextView, shouldInteractWithTextAttachment textAttachment: NSTextAttachment, inRange characterRange: NSRange) -> Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        print("Recieved Memory Warning")
    }
    
    func convertStringToDictionary(text: String) -> [String:AnyObject]? {
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
            do {
                return try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String:AnyObject]
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }
    
    func getWikiLink() {
        let name = (face.valueForKey("name") as! String)
        print(name)
        let nameArr = name.characters.split{$0 == " "}.map(String.init)
        var urlStr = nameArr[0]
        for i in 1..<nameArr.count {
            urlStr = urlStr + "_" + nameArr[i]
        }
        self.wikipedia = NSURL(string: "https://en.wikipedia.org/wiki/" + urlStr)
    }
    
}
