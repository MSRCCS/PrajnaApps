//
//  NSObject+Wrapper.h
//  ViewFinder
//
//  Created by Jacob Kohn on 7/8/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@interface NSObject (Wrapper)

- (int) test: (NSString*) a andSecond: (NSString*) b andThird: (void*) c;

- (NSString*) logText: (NSString*) toPrint;

- (BOOL) LoadModel: (NSString*) file_name second: (NSString*) file_type;

- (BOOL) LoadLabel: (NSString*) file_name second: (NSString*) file_type;

- (NSMutableDictionary*) runCNNOnFrame: (CVPixelBufferRef) pixelBuffer;

@end
