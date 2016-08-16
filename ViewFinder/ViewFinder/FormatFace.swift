//
//  FormatFace.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 8/11/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//


/*
 
 This file contains all the functions for formatting faces. 
 These functions are used for cropping and rotating faces.
 The CoreData functions for saving and loading faces are also defined in this file.
 
*/



import Foundation
import UIKit
import CoreData

var detectedFaces = [NSManagedObject]()

/*
 * This function rotates an image so that the eyes are parallel
 * @param: face: the face to use when rotating the image
 * @param: image: the image to rotate
 * @return: retusn the image after it has been rotated
*/
func rotateFace(face: CIFaceFeature, image: UIImage) -> UIImage {
    let xDistance = face.leftEyePosition.y - face.rightEyePosition.y
    let yDistance = face.leftEyePosition.x - face.rightEyePosition.x
    let hypotenuse = pythagorean(xDistance, b: yDistance)
    
    let rads = asin(yDistance / hypotenuse)
    
    let i = imageRotatedByDegrees(image, rads: rads)
    
    return i
}

/* Rotates an image a specified number of radians
 * @param: oldImage: image to rotate
 * @param: rads: number of radians to rotate the image by
 * @return: returns the rotated image
*/
func imageRotatedByDegrees(oldImage: UIImage, rads: CGFloat) -> UIImage {
    //Calculate the size of the rotated view's containing box for our drawing space
    let rotatedViewBox: UIView = UIView(frame: CGRectMake(0, 0, oldImage.size.width, oldImage.size.height))
    let t: CGAffineTransform = CGAffineTransformMakeRotation(rads)
    rotatedViewBox.transform = t
    let rotatedSize: CGSize = rotatedViewBox.frame.size
    //Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize)
    let bitmap: CGContextRef = UIGraphicsGetCurrentContext()!
    //Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width / 2, rotatedSize.height / 2)
    //Rotate the image context
    CGContextRotateCTM(bitmap, rads)
    //Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0)
    CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.height, oldImage.size.width), oldImage.CGImage!)
    
    let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return UIImage(CGImage: newImage.CGImage!, scale: oldImage.scale, orientation: oldImage.imageOrientation)
}

//returns the frame for the face box after it has been transformed for the screen size
private func transformFacialFeaturePosition(xPosition: CGFloat, yPosition: CGFloat, width: CGFloat, height: CGFloat, previewRect: CGRect, isMirrored: Bool) -> CGRect {
    
    var featureRect = CGRect(origin: CGPoint(x: xPosition, y: yPosition), size: CGSize(width: width, height: height))
    let widthScale = previewRect.size.width / 480.0
    let heightScale = previewRect.size.height / 640.0
    
    let transform = isMirrored ? CGAffineTransformMake(0, heightScale, -widthScale, 0, previewRect.size.width, 0) :
        CGAffineTransformMake(0, heightScale, widthScale, 0, 0, 0)
    
    featureRect = CGRectApplyAffineTransform(featureRect, transform)
    
    featureRect = CGRectOffset(featureRect, previewRect.origin.x, previewRect.origin.y)
    
    return featureRect
}

//Pythagorean Theorum function
func pythagorean(a: CGFloat, b: CGFloat) -> CGFloat {
    return sqrt((a * a) + (b * b))
}

//This function crops an image to a specified rect and then returns that image
func cropFace(image: UIImage, rect: CGRect) -> UIImage {
    let transformedRect = CGRect(x: rect.minY, y: rect.minX, width: rect.height, height: rect.width)
    
    let oddRect = CGRect(x: transformedRect.minY, y: image.size.width - transformedRect.minX - transformedRect.width, width: transformedRect.height, height: transformedRect.width)
    
    let cgimge = CGImageCreateWithImageInRect(image.CGImage!, oddRect)
    let im = UIImage(CGImage: cgimge!, scale: image.scale, orientation: image.imageOrientation)
    return im
}

/*This function matches a point to the nearest face.
 * This function is used to determine which faces match after rotating an image
 * @param: origin: the original point of the image
 * @param: list: list of facial features to match to the origin
 * @return: returns the CIFaceFeature that is closest to the origin point
*/
func matchFaceMethod(origin: CGPoint, list: [CIFaceFeature]) -> CIFaceFeature {
    var closest = 0
    var distance = getDistanceBetweenPoints(origin, two: list[0].bounds.origin)
    if(list.count > 1) {
        for i in 1..<list.count {
            let newDist = getDistanceBetweenPoints(origin, two: list[i].bounds.origin)
            if(newDist < distance) {
                closest = i
                distance = newDist
            }
        }
    }
    return list[closest]
}

/* Returns the distance between two points
 * @param: one: first point
 * @param: two: second point
 * @return: returns the distance between two points
*/
func getDistanceBetweenPoints(one: CGPoint, two: CGPoint) -> CGFloat {
    let xDist = one.x - two.x
    let yDist = one.y - two.y
    return pythagorean(xDist, b: yDist)
}

/* This function is called from the ImageCaptureVC and the AnalyzeUploadedImageVC
 * Saves a celebrity's face when APIs return true for JSON
 * @param: i: image to save
 * @param: origin: origin point of the face to save
 * @param: name: name that the API returns
*/
func saveFaceFromImage(i: UIImage, origin: CGPoint, name: String) {
    print("!")
    if(!alreadyHasFace(name)) {
        let context = CIContext()
        var options = [String : AnyObject]()
        options[CIDetectorAccuracy] = CIDetectorAccuracyLow
        options[CIDetectorTracking] = true
        let detector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: options)
        let cim = CIImage(image: i)
        var image = i
        
        print("!!")
        
        //gets face features
        let imageOptions = [CIDetectorImageOrientation : 6]
        let originalFeatures = detector!.featuresInImage(cim!, options: imageOptions) as! [CIFaceFeature]
        
        print("!!!")
        
        if(originalFeatures.count == 0) { return }
        
        print("!!!a")
        
        //finds rect for face
        let face = matchFaceMethod(origin, list: originalFeatures)
        
        print("!!!!")
        
        //rotates face
        if(face.rightEyePosition != face.leftEyePosition) {
            image = rotateFace(face, image: image)
        }
        
        print("!!!!!")
        
        //finds face rectangle again
        let rotatedCim = CIImage(image: image)
        let rotatedFeatures = detector!.featuresInImage(rotatedCim!, options: imageOptions) as! [CIFaceFeature]
        if(rotatedFeatures.count == 0) { return }
        let rotatedFace = matchFaceMethod(origin, list: rotatedFeatures)

        print("!!!!!!")
        
        //crops face
        image = cropFace(image, rect: rotatedFace.bounds)

        print("!!!!!!!")
        
        //saves
        saveFace(name, image: image)
        
        print("!!!!!!!!")
    }
}

//saves a face into CoreData
func saveFace(name: String, image: UIImage) {
    let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
    
    let managedContext = appDelegate.managedObjectContext
    
    let entity =  NSEntityDescription.entityForName("Face",
                                                    inManagedObjectContext:managedContext)
    
    let person = NSManagedObject(entity: entity!,
                                 insertIntoManagedObjectContext: managedContext)
    
    let imageData = UIImageJPEGRepresentation(image, 1.0)
    person.setValue(name, forKey: "name")
    person.setValue(imageData!, forKey: "image")
    
    do {
        try managedContext.save()
        detectedFaces.append(person)
    } catch let error {
        print("Could not save \(error), \((error as NSError).userInfo)")
    }
}

func loadFaces() {
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let managedContext = appDelegate.managedObjectContext
    let fetchRequest = NSFetchRequest(entityName: "Face")
    do {
        let results =
            try managedContext.executeFetchRequest(fetchRequest)
        detectedFaces = results as! [NSManagedObject]
    } catch let error as NSError {
        print("Could not fetch \(error), \(error.userInfo)")
    }
}

//returns true if there is already a stored face with the same name
func alreadyHasFace(name: String) -> Bool {
    for face in detectedFaces {
        if(face.valueForKey("name") as! String == name) {
            return true
        }
    }
    return false
}
