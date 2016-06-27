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
    
    init(x: Int, y: Int, height: Int, width: Int, caption: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        outline.frame = CGRect(x: x, y: y, width: width, height: height)
        outline.layer.borderColor = UIColor.yellowColor().CGColor
        outline.layer.borderWidth = 3.0
        self.addSubview(outline)
        
        self.caption.frame = CGRect(x: x, y: y + height, width: width, height: 24)
        self.caption.backgroundColor = UIColor.yellowColor()
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
        outline.layer.borderColor = UIColor.yellowColor().CGColor
        outline.layer.borderWidth = 3.0
        self.addSubview(outline)
        
        self.caption.frame = CGRect(x: x, y: y + height, width: width, height: 24)
        self.caption.backgroundColor = UIColor.yellowColor()
        self.caption.textColor = UIColor.blackColor()
        self.caption.text = caption
        self.caption.font = self.caption.font.fontWithSize(12)
        self.addSubview(self.caption)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}