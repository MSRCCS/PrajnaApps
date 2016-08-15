using UnityEngine;
using System.Collections;
using UnityEngine.VR.WSA.WebCam;
using System.Linq;
using System.Collections.Generic;
using UnityEngine.Networking;
using UnityEngine.UI;
using SimpleJSON;
using System.Text;
using UnityEngine.Windows.Speech;

//using System.Drawing;

public class Clicker : MonoBehaviour
{
    UnityWebRequest wrDescribe;
    UnityWebRequest wrFace;
    UnityWebRequest wrAzure;

    int iter = 0;
    public Text textBox;
    public Text modeBox;

    public MeshRenderer mesh;
    public static bool caption = true; // caption or faces
    public bool startedPhoto = false;
    public bool startedRoutine = false;
    public static bool newFace = false;

    private string keyFace = "4cb2b28396104278867114638f7a75b0";
    private string keyCv = "cbc1463902284471bf4aaae732da10a0";
    private string groupId = "office";
    private string personId = null;
    private string faceId = null;

    public List<byte> byteArray;
    private string dictationText = "";
    DictationRecognizer dictationRecognizer;

    void Start()
    {
        StartCoroutine(CapturePhoto());
    }

    void Update()
    {
        if (!startedPhoto && !startedRoutine && !newFace)
        {
            iter++;
            if ((GazeManager.changedGaze && iter > 40) || (iter > 350)) 
            {
                Debug.Log(iter);
                GazeManager.changedGaze = false;
                GazeManager.totalDiff = 0;
                iter = 0;
                StartCoroutine(CapturePhoto());
            }
        }
    }

    private IEnumerator CapturePhoto()
    {
        startedPhoto = true;
        Resolution res = PhotoCapture.SupportedResolutions.OrderBy((r) => r.width * r.height).First();
        PhotoCapture photoCapture = null;
        bool done = false;
        PhotoCapture.CreateAsync(false, (v) =>
        {
            photoCapture = v;
            done = true;
        });

        while (!done)
        {
            yield return null;
        }

        if (photoCapture == null)
        {
            // Debug.LogFormat("Failed to create PhotoCapture!");
            yield break;
        }
        CameraParameters cameraParameters = new CameraParameters();
        cameraParameters.hologramOpacity = 1.0f;
        cameraParameters.cameraResolutionWidth = res.width;
        cameraParameters.cameraResolutionHeight = res.height;
        cameraParameters.pixelFormat = CapturePixelFormat.JPEG; // changed - JPEG
        // Debug.LogFormat("Starting photo mode with {0}x{1}", cameraParameters.cameraResolutionWidth, cameraParameters.cameraResolutionWidth);
        done = false;
        PhotoCapture.PhotoCaptureResult result = default(PhotoCapture.PhotoCaptureResult);
        photoCapture.StartPhotoModeAsync(cameraParameters, false, (r) =>
        {
            result = r;
            done = true;
        });

        while (!done)
        {
            yield return null;
        }

        if (!result.success || result.resultType != PhotoCapture.CaptureResultType.Success)
        {
            // Debug.LogFormat("Failed to create start photo mode!");
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
        {
            yield return null;
        }
        if (!result.success || result.resultType != PhotoCapture.CaptureResultType.Success)
        {
            // Debug.LogFormat("Failed photo");
            yield break;
        }

        else if (result.resultType == PhotoCapture.CaptureResultType.Success)
        {
            // Debug.Log("Success photo");
        }

        done = false;
        photoCapture.StopPhotoModeAsync((r) =>
        {
            result = r;
            done = true;
        });

        while (!done)
        {
            yield return null;
        }

        byteArray = new List<byte>();
        photoCaptureFrame.CopyRawImageDataIntoBuffer(byteArray);

        if (caption)
        {
            Describe(byteArray);
        }
        else
        {
            Face(byteArray);
        }

        //ImagePost(byteArray);

        photoCapture.Dispose();
        startedPhoto = false;
    }

    void Describe (List<byte> array) // caption to textbox
    {
        startedRoutine = true;
        string url = "https://api.projectoxford.ai/vision/v1.0/describe?maxCandidates=1";
        wrDescribe = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        wrDescribe.SetRequestHeader("Ocp-Apim-Subscription-Key", keyCv);
        wrDescribe.SetRequestHeader("Content-Type", "application/octet-stream");
        wrDescribe.downloadHandler = new DownloadHandlerBuffer();
        wrDescribe.uploadHandler = new UploadHandlerRaw(array.ToArray());
        StartCoroutine(RequestDescribe());
    }

    IEnumerator RequestDescribe()
    {
        // Debug.Log("calling api");
        yield return wrDescribe.Send();

        if (wrDescribe.isError)
        {
            // Debug.Log(wrDescribe.error);
        }
        else
        {
            string json = wrDescribe.downloadHandler.text;
            // Debug.Log(json);

            textBox.text = JsonParse(json);
            // Debug.Log("textbox:" + JsonParse(json));
        }
        startedRoutine = false;
    }

    void Face (List<byte> array) // face identification (age and gender)
    {
        startedRoutine = true;
        string url = "https://api.projectoxford.ai/face/v1.0/detect?returnFaceId=true&returnFaceAttributes=age,gender";
        wrFace = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        wrFace.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        wrFace.SetRequestHeader("Content-Type", "application/octet-stream");
        wrFace.downloadHandler = new DownloadHandlerBuffer();
        wrFace.uploadHandler = new UploadHandlerRaw(array.ToArray());
        StartCoroutine(RequestFace());
    }

    IEnumerator RequestFace()
    {
        // Debug.Log("calling face");
        yield return wrFace.Send();

        if (wrFace.isError)
        {
            // Debug.Log(wrFace.error);
        }
        else
        {
            string json = wrFace.downloadHandler.text;
            if (ParseFace(json))
            {
                Debug.Log("faceID: " + faceId);
                FaceIdentify();
            }
        }
        startedRoutine = false;
    }

    void ImagePost (List<byte> array) // posts image to cloudinary
    {
        string url = "https://api.cloudinary.com/v1_1/dlsyvz4yn/auto/upload";
        WWWForm form = new WWWForm();
        form.AddBinaryData("file", array.ToArray());
        form.AddField("upload_preset", "tester");
        wrAzure = UnityWebRequest.Post(url, form);
        StartCoroutine(RequestImagePost(wrAzure));
    }

    IEnumerator RequestImagePost(UnityWebRequest req)
    {
        Debug.Log("posting request");
        yield return req.Send();

        if (req.isError)
        {
            Debug.Log(req.error);
        }
        else
        {
            Debug.Log("request success");
        }
    }

    void FaceIdentify() // identifies if tagged face is within group
    {
        string url = "https://api.projectoxford.ai/face/v1.0/identify";
        FaceIdentifyClass myClass = new FaceIdentifyClass();
        myClass.faceIds.Add(faceId);
        myClass.maxNumOfCandidatesReturned = 1;
        myClass.personGroupId = groupId;

        byte[] body = Encoding.UTF8.GetBytes(JsonUtility.ToJson(myClass));

        UnityWebRequest req = new UnityWebRequest(url, "POST");

        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.SetRequestHeader("Content-Type", "application/json");
        req.uploadHandler = new UploadHandlerRaw(body);
        req.downloadHandler = new DownloadHandlerBuffer();
        StartCoroutine(RequestFaceIdentify(req));
    }

    IEnumerator RequestFaceIdentify (UnityWebRequest req)
    {
        Debug.Log("request identify request");
        yield return req.Send();

        if (req.isError)
        {
            Debug.Log(req.error);
        }
        else
        {
            Debug.Log("request success");
            ParseFaceIdentify(req.downloadHandler.text);
        }
    }

    void ParseFaceIdentify(string json)
    {
        if (!json.Contains("personId")) // face is not part of person group
        {
            newFace = true;
            Debug.Log("unrecognized person");
            textBox.text = "Unrecognized person. Add?";
            Debug.Log(json);
        }
        else // face is part of person group
        {
            string id = JSON.Parse(json)[0]["candidates"][0]["personId"].Value;
            Debug.Log("JSON: !!!! " + json);
            Debug.Log("Person ID: " + id);
            PersonIdentify(id);
        }
    }

    void PersonIdentify (string personId) // gets name of person identified to be part of group
    {
        string url = "https://api.projectoxford.ai/face/v1.0/persongroups/" + groupId + "/persons/" + personId;
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbGET);
        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.downloadHandler = new DownloadHandlerBuffer();
        StartCoroutine(RequestPersonIdentify(req));
    }

    IEnumerator RequestPersonIdentify(UnityWebRequest req)
    {
        Debug.Log("request person identify request");
        yield return req.Send();

        if (req.isError)
        {
            Debug.Log(req.error);
        }
        else
        {
            Debug.Log("request success");
            string text = req.downloadHandler.text;
            GetPersonClass myClass = JsonUtility.FromJson<GetPersonClass>(text);
            textBox.text = myClass.name;
        }
    }

    void AddPerson (string name) // creates a person and adds to person group
    {
        string url = "https://api.projectoxford.ai/face/v1.0/persongroups/" + groupId + "/persons";
        CreatePersonClass myClass = new CreatePersonClass();
        myClass.name = name;

        byte[] body = Encoding.UTF8.GetBytes(JsonUtility.ToJson(myClass));

        UnityWebRequest req = new UnityWebRequest(url, "POST");

        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.SetRequestHeader("Content-Type", "application/json");
        req.downloadHandler = new DownloadHandlerBuffer();
        req.uploadHandler = new UploadHandlerRaw(body);
        StartCoroutine(RequestAddPerson(req));

    }

    IEnumerator RequestAddPerson(UnityWebRequest req)
    {
        Debug.Log("add person request");
        yield return req.Send();

        if (req.isError)
        {
            Debug.Log(req.error);
        }
        else
        {
            Debug.Log("request success");
            string text = req.downloadHandler.text;
            Debug.Log("json add: " + text);
            personId = JSON.Parse(text)["personId"].Value;
            AddPicture();
        }
    }

    void AddPicture () // adds the taken picture for the person who has just been created
    {
        string url = "https://api.projectoxford.ai/face/v1.0/persongroups/" + groupId + "/persons/" + personId + "/persistedFaces";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.SetRequestHeader("Content-Type", "application/octet-stream");
        req.downloadHandler = new DownloadHandlerBuffer();
        req.uploadHandler = new UploadHandlerRaw(byteArray.ToArray());
        StartCoroutine(RequestAddPicture(req));
    }


    IEnumerator RequestAddPicture(UnityWebRequest req)
    {
        Debug.Log("add picture request");
        yield return req.Send();

        if (req.isError)
        {
            Debug.Log(req.error);
        }
        else
        {
            Debug.Log("request add success");
            string text = req.downloadHandler.text;
            Debug.Log("JSON! " + text);
            Debug.Log(JSON.Parse(text)["persistedFaceId"].Value);
            textBox.text = "Successfully added " + dictationText + "!";
            TrainGroup();
        }
    }

    void TrainGroup () // trains the person group after adding new member
    {
        string url = "https://api.projectoxford.ai/face/v1.0/persongroups/" + groupId + "/train";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.downloadHandler = new DownloadHandlerBuffer();
        StartCoroutine(RequestTrain(req));
    }

    IEnumerator RequestTrain (UnityWebRequest req)
    {
        Debug.Log("train group request");
        yield return req.Send();

        if (req.isError)
        {
            Debug.Log(req.error);
        }
        else
        {
            Debug.Log("request success");
            newFace = false;
        }
    }

    bool ParseFace(string json) 
    {
        bool boolRet = false;
        var parsed = JSON.Parse(json);
        int elements = SubstringNumber(json, "faceId");
        StringBuilder ret = new StringBuilder();
        if (elements > 0)
        {
            boolRet = true;
            faceId = parsed[0]["faceId"].Value;
            for (int i = 0; i < elements; i++)
            {
                ret.Append(string.Format("Age: {0}, Gender: {1} \n", parsed[i]["faceAttributes"]["age"].Value, parsed[i]["faceAttributes"]["gender"].Value));
            }
        }
        else
        {
            ret.Append("No faces");
        }
        textBox.text = ret.ToString();
        return boolRet;
    }

    int SubstringNumber(string json, string substring)
    {
        // Loop through all instances of the string 'text'.
        int count = 0;
        int i = 0;
        while ((i = json.IndexOf(substring, i)) != -1)
        {
            i += substring.Length;
            count++;
        }
        return count;
    }

    string JsonParse (string json)
    {
        int start = json.IndexOf("text\":\"") + 7;
        int end = json.IndexOf("confi") - 3;
        return json.Substring(start, (end - start));
    }

    public void ChangeMode()
    {
        caption = !caption;
        newFace = false;

        if (caption)
        {
            modeBox.text = "Mode: Caption";
        }

        else
        {
            modeBox.text = "Mode: Faces";
        }

        if (!startedPhoto && !startedRoutine)
        {
            StartCoroutine(CapturePhoto());
        }
    }

    public void StartRecording()
    {
        PhraseRecognitionSystem.Shutdown();
        int samplingRate, unused;

        Microphone.GetDeviceCaps("", out unused, out samplingRate);
        Debug.Log(samplingRate);

        dictationRecognizer = new DictationRecognizer();
        dictationRecognizer.DictationResult += DictationRecognizer_DictationResult;
        dictationRecognizer.DictationComplete += DictationRecognizer_DictationComplete;

        dictationText = "";
        dictationRecognizer.Start();
        Debug.Log("started recording");
        textBox.text = "Listening";
        Microphone.Start("", false, 10, samplingRate);
    }

    private void DictationRecognizer_DictationResult(string text, ConfidenceLevel confidence)
    {
        dictationText += text;
        Debug.Log("entered: " + dictationText);

        if (dictationRecognizer.Status == SpeechSystemStatus.Running)
        {
            dictationRecognizer.Stop();
        }

        Microphone.End("");
        Debug.Log("finished result");
    }

    private void DictationRecognizer_DictationComplete(DictationCompletionCause cause)
    {
        Debug.Log("entered complete");
        PhraseRecognitionSystem.Restart();
        AddPerson(dictationText);
    }
}