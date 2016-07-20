//
//  Global.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 7/19/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

/*
 This file defines global variables to be used throughout the applicaiton
 
 */

import Foundation
import UIKit

let languages = [["name": "Arabic", "code": "ar"], ["name": "Chinese", "code": "zh-CHS"], ["name": "Dutch", "code": "nl"], ["name": "English", "code": "en"], ["name": "French", "code": "fr"], ["name": "German", "code": "de"], ["name": "Hebrew", "code": "he"], ["name": "Hindi", "code": "hi"], ["name": "Indonesian", "code": "id"], ["name": "Italian", "code": "it"], ["name": "Japanese", "code": "ja"], ["name": "Korean", "code": "ko"], ["name": "Portuguese", "code": "pt"], ["name": "Russian", "code": "ru"], ["name": "Spanish", "code": "es"], ["name": "Turkish", "code": "tr"], ["name": "Vietnamese", "code": "vi"]]

func getLanguageFromCode(code: String) -> String {
    for language in languages {
        if(language["code"] == code) {
            return language["name"]!
        }
    }
    return "Not a Real Language Code"
}

var firstTime = Bool()


//Instructions

let introductionIns = "The ViewFinder iPhone application allows the user (you) to identify faces, words, and objects in video or images. Use the above topic picker to look through the instructions on how to use the ViewFinder application."

let threeModesIns = "There are three modes in the app: Live, Still Image, and Upload Image. When the app launches it will automatically use live mode. To go from live to still image just swipe left or touch the button titled “Photo” in the bottom right hand corner. To go from still to live swipe right on the still screen or touch the button titled “Live” in the bottom left hand corner. The Upload Image mode can be used in the bottom right hand corner of the still image mode. Be sure to approve access to photos for the upload image feature to work."

let usingTensorflowIns = "The app's default setting for live mode is to run Tensorflow. When you open the app for the first time, the bars across the top of the screen are the top five (or fewer) results from Tensorflow and their prediction value. The prediction value is how confident the model is that the object is in the frame. The outputs are ordered by how high their prediction values are. No prediction value of less than 5 will be displayed."

let usingTheMenuIns = "The menu is in the top right hand corner of the screen. When you click on it you will see three options: Facial Recognition, Translation, and Tensorflow. If you click on the first two the menu will change to offer you more options."

let facialRecognitionIns = "There are currently two ways to use the facial recognition, a normal and celebrity mode. The normal mode will recognize faces and and give an estimation on how old the person is along with their gender. The celebrity mode will display the name of a celebrity if they are present. These results are obtained from the AnalyzeImage API."

let translationIns = "There are many different languages that the app can translate into. You do not need to specify the language that you are translating from, the app will detect that by itself. Results are obtained from calling the OCR API to get the text in the image followed by a call to the Microsoft Translator API."

let liveTranslationIns = "To use live translation, the camera must be held steady. When the process starts there will be a gray process indicator just under the menu button that looks like a spinning wheel. If the API cannnot read the words in the image the process indicator will disappear and the translation will cancel. If the translation does succeed, two buttons will apear under the menu button. The button with the D holds the details of the translation, click on that to see what was returned. The button with the X will close that translation and allow the user to do another one."

let uploadImageIns = "If you are uploading an image, the API used to analyze the image is decided by what the selected menu option is in the still image mode. If you want to translate words in the image you are uploading, make sure you set the mode to translation from the still image capture screen."

let troubleshootingIns = "“I blew it and didn’t allow access to Camera or Photos”:\n\nGo to the settings for this app and toggle to allow access to Camera, Photos, and probably cellular data too (the only feature that works offline is Tensorflow)\n\n“The camera stopped running”:\n\nEither restart the app or switch between modes."