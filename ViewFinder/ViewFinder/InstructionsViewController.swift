//
//  InstructionsViewController.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/18/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit

class InstructionsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var picker: UIPickerView!
    
    let sections:[String] = ["Introduction", "Three Modes", "Using the Menu", "Object Detection", "Facial Recognition", "Translation", "Uploading an Image", "Troubleshooting"]
    
    let sectionDetails:[String] = [introductionIns, threeModesIns, usingTheMenuIns, usingTensorflowIns, facialRecognitionIns, translationIns, uploadImageIns, troubleshootingIns]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        picker.delegate = self
        picker.dataSource = self
        
        textView.text = introductionIns
        textView.textAlignment = NSTextAlignment.Left
        textView.font = UIFont(name: (textView.font?.fontName)!, size: 18.0)
    }
    
    override func didReceiveMemoryWarning() {
        //
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return sections.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return sections[row]
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        textView.text = sectionDetails[row]
    }
    
    
}
