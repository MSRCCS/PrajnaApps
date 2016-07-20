ViewFinder

**ViewFinder** is an iOS apps that allows the user to identify object in image/video

Adding Tensorflow Into Your ViewFinder Xcode Project

1. Download the tensorflow zip from: https://github.com/tensorflow/tensorflow

2. Download Inception V1: https://storage.googleapis.com/download.tensorflow.org/models/inception5h.zip

3.  Extract the label and graph files from the Inception V1 zip and drag into the file inspector of the Xcode Project (add only to TensorflowViewFinder Target)

4. Run the build_all_os.sh script (tensorflow-master/tensorflow/contrib/makefile/build_all_ios.sh)
Note: this will take a long time, likely over an hour.

5. Under Build Settings:
5a. Change Header Search Paths to reflect where you saved the tensorflow file. It should include these directories
- The root folder of tensorflow
- tensorflow/contrib/makefile/downloads/protobuf/src
- tensorflow/contrib/makefile/downloads
- tensorflow/contrib/makefile/downloads/eigen-latest
- tensorflow/contrib/makefile/gen/proto
5b. Change Library Search Paths to reflect where you saved the tensorflow file. It must have:
- tensorflow/contrib/makefile/gen/lib
- tensorflow/contrib/makefile/gen/protobuf_ios/lib
5c. Under linking, change Other Linker Flags to -force_load (tensorflow-master directory)/tensorflow/contrib/makefile/gen/lib/libtensorflow-core.a

6. Under Build Phases -> Link Binary With Libraries remove both .a files. Then add the libprotobuf-lite.a and libprotobuf.a files from your tesnorflow folder /tensorflow/contrib/makefile/gen/protobuf_ios/lib folder

7. Set C++ Language Dialect to GNU++11 or GNU++14 and C++ Standard Library to libc++

8. Disable bitcode in project settings

9. Remove all uses of the -all_load flag
