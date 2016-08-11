//
//  FormatFace.swift
//  ViewFinder
//
//  Created by Jacob Kohn on 8/11/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit
func rotateFace(face: CIFaceFeature, image: UIImage) -> UIImage {
    let xDistance = face.leftEyePosition.y - face.rightEyePosition.y
    let yDistance = face.leftEyePosition.x - face.rightEyePosition.x
    let hypotenuse = pythagorean(xDistance, b: yDistance)
    
    let rads = asin(yDistance / hypotenuse)
    
    let i = imageRotatedByDegrees(image, rads: rads)
    
    return i
}

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

//returns the frame for the face box
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

func pythagorean(a: CGFloat, b: CGFloat) -> CGFloat {
    return sqrt((a * a) + (b * b))
}

func cropFace(image: UIImage, rect: CGRect) -> UIImage {
    let transformedRect = CGRect(x: rect.minY, y: rect.minX, width: rect.height, height: rect.width)
    
    let oddRect = CGRect(x: transformedRect.minY, y: image.size.width - transformedRect.minX - transformedRect.width, width: transformedRect.height, height: transformedRect.width)
    
    let cgimge = CGImageCreateWithImageInRect(image.CGImage!, oddRect)
    let im = UIImage(CGImage: cgimge!, scale: image.scale, orientation: image.imageOrientation)
    return im
}
