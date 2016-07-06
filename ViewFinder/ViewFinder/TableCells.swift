//
//  TableCells.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/5/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class TranslationTableCell: UITableViewCell {
    

    @IBOutlet weak var fromLabel: UILabel!
    @IBOutlet weak var originalLabel: UILabel!
    @IBOutlet weak var toLabel: UILabel!
    @IBOutlet weak var translatedLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}