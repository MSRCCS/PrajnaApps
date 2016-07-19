//
//  TranslateWordBox.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 6/27/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class TranslateWordBox: UIView {
    
    let outline = UILabel()
    let detailButton = UIButton()
    
    init(x: Int, y: Int, height: Int, width: Int, caption: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        outline.frame = CGRect(x: x, y: y, width: width, height: height)
        outline.backgroundColor = UIColor.whiteColor()
        outline.textColor = UIColor.blackColor()
        outline.adjustsFontSizeToFitWidth = true
        self.addSubview(outline)
    }
    
    init(frame: CGRect, caption: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let x = frame.minX
        let y = frame.minY
        let height = frame.height
        let width = frame.width
        
        outline.frame = CGRect(x: x, y: y, width: width, height: height)
        outline.backgroundColor = UIColor.whiteColor()
        outline.textColor = UIColor.blackColor()
        outline.adjustsFontSizeToFitWidth = true
        self.addSubview(outline)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}