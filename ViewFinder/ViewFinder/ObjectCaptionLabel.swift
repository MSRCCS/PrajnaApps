//
//  ObjectCaptionLabel.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/11/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class ObjectCaptionLabel: UIView {
    
    var captionLabel = UILabel()
    var valueLabel = UILabel()
    let color = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.6)
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(pos: Int, caption: String, value: Float) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        self.captionLabel.frame = CGRect(x: 0, y: 60 + 24 * pos, width: Int(UIScreen.mainScreen().bounds.width) - 40, height: 24)
        self.valueLabel.frame = CGRect(x: Int(UIScreen.mainScreen().bounds.width) - 40, y: 60 + 24 * pos, width: 40, height: 24)
        captionLabel.text = caption
        valueLabel.text = String(value)
        captionLabel.backgroundColor = color
        valueLabel.backgroundColor = color
        captionLabel.textColor = UIColor.whiteColor()
        valueLabel.textColor = UIColor.whiteColor()
        self.addSubview(captionLabel)
        self.addSubview(valueLabel)
    }
}