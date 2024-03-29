//
//  FaceDetectionBox.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/22/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class FaceDetectionBox: UILabel {
    
    let outline = UILabel()
    let caption = UILabel()
    var featureID = Int()
    var inFrame = Bool()
    
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    }
    
    init(x: Int, y: Int, height: Int, width: Int, caption: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        outline.frame = CGRect(x: x, y: y, width: width, height: height)
        outline.layer.borderColor = UIColor.whiteColor().CGColor
        outline.layer.borderWidth = 3.0
        self.addSubview(outline)
        
        if(width < 70) {
            self.caption.frame = CGRect(x: x, y: y + height, width: 70, height: 24)
        } else {
            self.caption.frame = CGRect(x: x, y: y + height, width: width, height: 24)
        }
        self.caption.backgroundColor = UIColor.whiteColor()
        self.caption.textColor = UIColor.blackColor()
        self.caption.text = caption
        self.caption.font = self.caption.font.fontWithSize(12)
        self.addSubview(self.caption)
    }
    
    init(frame: CGRect, caption: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let x = frame.minX
        let y = frame.minY
        let height = frame.height
        let width = frame.width
        
        outline.frame = CGRect(x: x, y: y, width: width, height: height)
        outline.layer.borderColor = UIColor.whiteColor().CGColor
        outline.layer.borderWidth = 3.0
        self.addSubview(outline)
        
        if(width < 70) {
            self.caption.frame = CGRect(x: x, y: y + height, width: 70, height: 24)
        } else {
            self.caption.frame = CGRect(x: x, y: y + height, width: width, height: 24)
        }
        
        self.caption.backgroundColor = UIColor.whiteColor()
        self.caption.textColor = UIColor.blackColor()
        self.caption.text = caption
        self.caption.font = self.caption.font.fontWithSize(12)
        self.addSubview(self.caption)
    }
    
    init(frame: CGRect, featureID: Int, inFrame: Bool) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let x = frame.minX
        let y = frame.minY
        let height = frame.height
        let width = frame.width
        self.featureID = featureID
        self.inFrame = inFrame
        
        outline.frame = CGRect(x: x, y: y, width: width, height: height)
        outline.layer.borderColor = UIColor.whiteColor().CGColor
        outline.layer.borderWidth = 3.0
        self.addSubview(outline)
        
        if(width < 70) {
            self.caption.frame = CGRect(x: x, y: y + height, width: 70, height: 24)
        } else {
            self.caption.frame = CGRect(x: x, y: y + height, width: width, height: 24)
        }
        self.caption.backgroundColor = UIColor.whiteColor()
        self.caption.textColor = UIColor.blackColor()
        self.caption.font = self.caption.font.fontWithSize(12)
        self.addSubview(self.caption)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
