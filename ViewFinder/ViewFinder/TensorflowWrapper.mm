//
//  NSObject+Wrapper.m
//  ViewFinder
//
//  Created by Jacob Kohn on 7/8/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

#import <CoreVideo/CoreVideo.h>
#import "TensorflowWrapper.h"
#include "tensorflow_utils.h"
#include "tensorflow/core/public/session.h"
#include "third_party/eigen3/unsupported/Eigen/CXX11/Tensor"

/*
This is the implementation for the Tensorflow Wrapper
*/

@implementation NSObject (Wrapper)

std::unique_ptr<tensorflow::Session> tf_session;
std::vector<std::string> labels;

- (int) test: (NSString*) a andSecond: (NSString*) b andThird: (void*) c
{
    return 0;
}

- (NSString*) logText: (NSString*) toPrint
{
    return toPrint;
}

- (NSString*) LoadModel:(NSString *)file_name second:(NSString *)file_type
{
    return LoadModel(file_name, file_type, &tf_session);
}

- (NSString*) LoadLabel: (NSString*) file_name second: (NSString*) file_type
{
    return LoadLabels(file_name, file_type, &labels);
}

- (NSMutableDictionary*) runCNNOnFrame: (CVPixelBufferRef) pixelBuffer
{
    NSLog(@"%s", "!");
    if(pixelBuffer != NULL) {
        
        const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
        const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
        const int fullHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        unsigned char *sourceBaseAddr = (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
        
        int image_height;
        unsigned char *sourceStartAddr;
        if (fullHeight <= image_width) {
            image_height = fullHeight;
            sourceStartAddr = sourceBaseAddr;
        } else {
            image_height = image_width;
            const int marginY = ((fullHeight - image_width) / 2);
            sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
        }
        
        const int image_channels = 4;
        
        const int wanted_width = 224;
        const int wanted_height = 224;
        const int wanted_channels = 3;
        const float input_mean = 117.0f;
        const float input_std = 1.0f;
        
        tensorflow::Tensor image_tensor(
                                        tensorflow::DT_FLOAT,
                                        tensorflow::TensorShape(
                                                                {1, wanted_height, wanted_width, wanted_channels}));
        auto image_tensor_mapped = image_tensor.tensor<float, 4>();

        tensorflow::uint8 *in = sourceStartAddr;

        float *out = image_tensor_mapped.data();
        for (int y = 0; y < wanted_height; ++y) {
            NSLog(@"%i", y);
            float *out_row = out + (y * wanted_width * wanted_channels);

            for (int x = 0; x < wanted_width; ++x) {
                NSLog(@"%i", x);
            const int in_x = (y * image_width) / wanted_width;
                const int in_y = (x * image_height) / wanted_height;
                tensorflow::uint8 *in_pixel = in + (in_y * image_width * image_channels) + (in_x * image_channels);
                float *out_pixel = out_row + (x * wanted_channels);

                for (int c = 0; c < wanted_channels; ++c) {
                    out_pixel[c] = (in_pixel[c] - input_mean) / input_std;
                    NSLog(@"%i", c);
                }
            }
        }

        NSLog(@"%s", "!!!!");
        //gets predictions
        if (tf_session.get()) {
            std::string input_layer = "input";
            std::string output_layer = "output";
            std::vector<tensorflow::Tensor> outputs;
            tensorflow::Status run_status = tf_session->Run(
                                                            {{input_layer, image_tensor}}, {output_layer}, {}, &outputs);
            if (!run_status.ok()) {
                LOG(ERROR) << "Running model failed:" << run_status;
            } else {
                tensorflow::Tensor *output = &outputs[0];       //outputs has one "Tensor"
                
                auto predictions = output->flat<float>();       //creates "predictions" array of the predictions for all objects that it sees
                
                //sets the dictionary of things that it has detected
                NSMutableDictionary *newValues = [NSMutableDictionary dictionary];
                for (int index = 0; index < predictions.size(); index += 1) {
                    const float predictionValue = predictions(index);
                    if (predictionValue > 0.05f) {
                        std::string label = labels[index]; //edited - used to be index % predictions.size
                        
                        NSString *labelObject = [NSString stringWithCString:label.c_str()];
                        NSNumber *valueObject = [NSNumber numberWithFloat:predictionValue];
                        [newValues setObject:valueObject forKey:labelObject];

                        predictions(index);
                    }
                }
                return newValues;
            }
        }
        NSLog(@"%s", "Could not run model");
        return nil;
    }
    NSLog(@"%s", "Pixel Buffer Was NULL");
    return nil;
}
@end
