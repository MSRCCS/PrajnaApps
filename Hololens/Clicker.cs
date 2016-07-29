using UnityEngine;
using System.Collections;
using UnityEngine.VR.WSA.WebCam;
using System.Linq;
using System;
using System.Collections.Generic;
using System.IO;


// Takes a picture on start, converts to byte[], uploads to visual texture (untested)
public class Clicker : MonoBehaviour
{
    void Start()
    {
        StartCoroutine(CapturePhoto());
    }

    private IEnumerator CapturePhoto()
    {
        Resolution res = PhotoCapture.SupportedResolutions.OrderBy((r) => r.width * r.height).First();

        PhotoCapture photoCapture = null;
        bool done = false;

        PhotoCapture.CreateAsync(false, (v) =>
        {
            photoCapture = v;
            done = true;
        });

        while (!done)
            yield return null;

        if (photoCapture == null)
        {
            Debug.LogFormat("Failed to create PhotoCapture!");
            yield break;
        }

        CameraParameters cameraParameters = new CameraParameters();
        cameraParameters.hologramOpacity = 1.0f;
        cameraParameters.cameraResolutionWidth = res.width;
        cameraParameters.cameraResolutionHeight = res.height;
        cameraParameters.pixelFormat = CapturePixelFormat.BGRA32;

        Debug.LogFormat("Starting photo mode with {0}x{1}", cameraParameters.cameraResolutionWidth, cameraParameters.cameraResolutionWidth);

        done = false;
        PhotoCapture.PhotoCaptureResult result = default(PhotoCapture.PhotoCaptureResult);
        photoCapture.StartPhotoModeAsync(cameraParameters, false, (r) =>
        {
            result = r;
            done = true;
        });

        while (!done)
            yield return null;

        if (!result.success || result.resultType != PhotoCapture.CaptureResultType.Success)
        {
            Debug.LogFormat("Failed to create start photo mode!");
            yield break;
        }

        done = false;
        PhotoCaptureFrame photoCaptureFrame = null;
        photoCapture.TakePhotoAsync((r, f) =>
        {
            photoCaptureFrame = f;
            result = r;
            done = true;
        });

        while (!done)
            yield return null;

        if (!result.success || result.resultType != PhotoCapture.CaptureResultType.Success)
        {
            Debug.LogFormat("Failed photo");
            yield break;
        }
        else
        {
            Debug.Log("Success photo");
        }

        done = false;
        photoCapture.StopPhotoModeAsync((r) =>
        {
            result = r;
            done = true;
        });

        while (!done)
            yield return null; 

        List<byte> byteArray = new List<byte>();
        photoCaptureFrame.CopyRawImageDataIntoBuffer(byteArray);

        Texture2D newTexture = new Texture2D(cameraParameters.cameraResolutionWidth, cameraParameters.cameraResolutionHeight);
        photoCaptureFrame.UploadImageDataToTexture(newTexture);

        Stream s = new MemoryStream(byteArray.ToArray());

        photoCapture.Dispose();
    }

    /*async void Describe(Stream message)
    {
        VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
        string ret = "Please first attach an image or enter an image URL.";
        AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")));
        ret = analysisResult.Description.Captions[0].Text;
        Debug.Log(ret);
    }*/


}
