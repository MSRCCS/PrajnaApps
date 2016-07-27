ViewFinder

**ViewFinder** is an iOS apps that allows the user to identify object in image/video

Adding Tensorflow Into Your ViewFinder Xcode Project

1. Download Inception V1: https://storage.googleapis.com/download.tensorflow.org/models/inception5h.zip

2.  Extract the label and graph files from the Inception V1 zip and drag into the file inspector of the Xcode Project (add only to TensorflowViewFinder Target)

3. Run the build_all_ios.sh script in tensorflow/tensorflow/contrib/makefile folder. It will take a long time.

4. Run the ViewFinderTensorflow projcet.
