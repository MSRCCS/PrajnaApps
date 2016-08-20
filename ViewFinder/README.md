ViewFinder

**ViewFinder** is an iPhone apps that allows the user to identify object in image/video. 

To build the ViewFinder iPhone App, you will need to upgrade your phone to iOS 10 (This is because Azure iOS library requires iOS 10, and when ViewFinder uses AZSClient.framework, the phone needs to be upgraded to iOS 10). 

Please execute the following procedure:

1. Pull git submodules. 

Please pull down submodules azure-storage-ios and tensorflow by uses git submodules init and git submoudles update.

2. Download Inception V1: https://storage.googleapis.com/download.tensorflow.org/models/inception5h.zip

3.  Extract the label and graph files from the Inception V1 zip and drag into the file inspector of the Xcode Project (add only to TensorflowViewFinder Target)

4.  Run the build_all_ios.sh script in tensorflow/tensorflow/contrib/makefile folder. It will take about 20 minutes.

5.  Open AZSClient.xcodeproj under azure-storage-ios/Lib/Azure Storage Client Library. Build both target (library and AZSClient framework). 
    AZSClient.framework will be placed under your desktop folder. Please drag this to ViewFinder. 

4. Build the scheme ViewFinderTensorflow projcet.
