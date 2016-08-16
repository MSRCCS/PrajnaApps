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
using System;


public class Clicker : MonoBehaviour
{
    int iter = 0;
    public Text textBox;
    public Text modeBox;
    public Image image;

    public static int mode = 0;
    public static int prajnaMode = -1;

    public bool startedPhoto = false;
    public bool startedRoutine = false;
    public static bool newFace = false;

    private string keyFace = "4cb2b28396104278867114638f7a75b0";
    private string keyCv = "cbc1463902284471bf4aaae732da10a0";
    private string groupId = "office";
    private string personId = null;
    private string faceId = null;

    public static List<byte> byteArray;
    private string dictationText = "";
    DictationRecognizer dictationRecognizer;

    private static List<string> providerNames = null;
    private static List<string> classifierNames = null;
    private static List<string> classifierIds = null;
    private static int classifiersFound = 0;
    private static bool providersFound = false;

    public static int recordingMethod;

    void Start()
    {
        StartCoroutine(CapturePhoto());
    }

    void Update()
    {
        if (!startedPhoto && !startedRoutine && !newFace)
        {
            iter++;
            if (((GazeManager.changedGaze && iter > 40) || (iter > 350)) && !(classifierNames != null && mode == 2 && prajnaMode == -1))
            {
                //Debug.Log(iter);
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

        Resolution res = PhotoCapture.SupportedResolutions.OrderBy((r) => r.width * r.height).First(); // now takes highest res possible
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
            // //Debug.LogFormat("Failed to create PhotoCapture!");
            yield break;
        }
        CameraParameters cameraParameters = new CameraParameters();
        cameraParameters.hologramOpacity = 1.0f;
        cameraParameters.cameraResolutionWidth = res.width;
        cameraParameters.cameraResolutionHeight = res.height;
        cameraParameters.pixelFormat = CapturePixelFormat.JPEG; // changed - JPEG
        Debug.LogFormat("Starting photo mode with {0}x{1}", cameraParameters.cameraResolutionWidth, cameraParameters.cameraResolutionHeight);
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
            // //Debug.LogFormat("Failed to create start photo mode!");
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
            // //Debug.LogFormat("Failed photo");
            yield break;
        }

        else if (result.resultType == PhotoCapture.CaptureResultType.Success)
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
        {
            yield return null;
        }

        byteArray = new List<byte>();
        photoCaptureFrame.CopyRawImageDataIntoBuffer(byteArray);

        photoCapture.Dispose();


        if (mode == 0)
        {
            Describe();
        }
        else if (mode == 1)
        {
            Face();
        }

        else if (prajnaMode == -1)
        {
            AllClassifiers(true);
        }
        else
        {
            PrajnaHub();
        }

        startedPhoto = false;

        ImagePost();
        StopCoroutine("CapturePhoto");
    }

    IEnumerator MakeRequest(UnityWebRequest req, Action<string> act, bool actionToDo)
    {
        ////Debug.Log("making request");
        startedRoutine = true;
        yield return req.Send();

        if (req.isError)
        {
            //Debug.Log("request error");
            //Debug.Log(req.error);
        }
        else
        {
            string json = req.downloadHandler.text;
            ////Debug.Log("request json: \n" + json);
            if (actionToDo)
            {
                act(json);
            }
        }
        startedRoutine = false;
        StopCoroutine("MakeRequest");
    }

    void ImagePanel() // displays captured image on panel on hololens
    {
        Texture2D texture = new Texture2D(2, 2);
        texture.LoadImage(byteArray.ToArray());
        image.sprite = Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), new Vector2(0, 0));

        //Debug.Log("posted image sprite");
    }

    void Describe() // caption to textbox
    {
        mode = 0;
        string url = "https://api.projectoxford.ai/vision/v1.0/describe?maxCandidates=1";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyCv);
        req.SetRequestHeader("Content-Type", "application/octet-stream");
        req.downloadHandler = new DownloadHandlerBuffer();
        req.uploadHandler = new UploadHandlerRaw(byteArray.ToArray());
        StartCoroutine(MakeRequest(req, ParseDescribe, true));
    }

    void Face() // face identification (age and gender)
    {
        mode = 1;
        string url = "https://api.projectoxford.ai/face/v1.0/detect?returnFaceId=true&returnFaceAttributes=age,gender";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.SetRequestHeader("Content-Type", "application/octet-stream");
        req.downloadHandler = new DownloadHandlerBuffer();
        req.uploadHandler = new UploadHandlerRaw(byteArray.ToArray());
        StartCoroutine(MakeRequest(req, ParseFace, true));
    }

    void ImagePost() // posts image to cloudinary
    {
        string url = "https://api.cloudinary.com/v1_1/dlsyvz4yn/auto/upload";
        WWWForm form = new WWWForm();
        form.AddBinaryData("file", byteArray.ToArray());
        form.AddField("upload_preset", "tester");
        UnityWebRequest req = UnityWebRequest.Post(url, form);
        req.downloadHandler = new DownloadHandlerBuffer();
        StartCoroutine(MakeRequest(req, null, false));
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
        StartCoroutine(MakeRequest(req, ParseFaceIdentify, true));
    }

    void ParseFaceIdentify(string json)
    {
        if (!json.Contains("personId")) // face is not part of person group
        {
            newFace = true;
            //Debug.Log("unrecognized person");
            textBox.text = "Unrecognized person. Add?";
            //Debug.Log(json);
        }
        else // face is part of person group
        {
            string id = JSON.Parse(json)[0]["candidates"][0]["personId"].Value;
            //Debug.Log("JSON: !!!! " + json);
            //Debug.Log("Person ID: " + id);
            PersonIdentify(id);
        }
    }

    void PersonIdentify(string personId) // gets name of person identified to be part of group
    {
        string url = "https://api.projectoxford.ai/face/v1.0/persongroups/" + groupId + "/persons/" + personId;
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbGET);
        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.downloadHandler = new DownloadHandlerBuffer();
        StartCoroutine(MakeRequest(req, ParsePersonIdentify, true));
    }

    void ParsePersonIdentify (string json)
    {
        GetPersonClass myClass = JsonUtility.FromJson<GetPersonClass>(json);
        textBox.text = myClass.name;
    }

    void AddPerson(string name) // creates a person and adds to person group
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
        StartCoroutine(MakeRequest(req, ParseAddPerson, true));

    }

    void ParseAddPerson (string json)
    {
        //Debug.Log("json add: " + json);
        personId = JSON.Parse(json)["personId"].Value;
        AddPicture();
    }

    void PrajnaHub()
    {
        mode = 2;
        string url = "http://vm-hub.trafficmanager.net/Vhub/Process/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/" + classifierIds[prajnaMode] + "/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/636064468986830000/0/SecretKeyShouldbeLongerThan10";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        req.downloadHandler = new DownloadHandlerBuffer();
        req.uploadHandler = new UploadHandlerRaw(byteArray.ToArray());
        StartCoroutine(MakeRequest(req, ParsePrajnaHub, true));
    }

    void ParsePrajnaHub(string json)
    {
        if (json != null)
        {
            StringBuilder sb = new StringBuilder();
            if (json.Contains("CategoryName"))
            {
                int i = 0;
                while ((i = json.IndexOf("CategoryName", i)) > 0)
                {
                    i += 17;
                    sb.Append(json.Substring(i, (json.IndexOf(",", i) - 2 - i)) + "  ");
                }
                textBox.text = sb.ToString();
            }
            else if (json.Contains("Description") && !json.Contains("AuxResult"))
            {
                PrajnaHubClass myClass = JsonUtility.FromJson<PrajnaHubClass>(json);
                string description = myClass.Description;
                if (description.Contains(";")) // eg #office
                {
                    textBox.text = description.Substring(0, description.IndexOf(";"));
                }
                else if (description.Length > 2)
                {
                    textBox.text = description;
                }
                else
                {
                    textBox.text = "Nothing found";
                }
            }
            else
            {
                textBox.text = "Nothing found";
            }
        }
        else
        {
            textBox.text = "Request failed";
        }
    }

    void AllProviders ()
    {
        mode = 2;
        providersFound = false;
        providerNames = new List<string>();
        string url = "http://vm-hub.trafficmanager.net/Vhub/GetActiveProviders/00000000-0000-0000-0000-000000000000/" + TimeFormat() + "/0/SecretKeyShouldbeLongerThan10";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbGET);
        req.downloadHandler = new DownloadHandlerBuffer();
        StartCoroutine(MakeRequest(req, ParseAllProviders, true));
    }

    void ParseAllProviders (string json)
    {
        int start = 0;
        while ((start = json.IndexOf("EngineName", start)) > 0)
        {
            start += 13;
            int end = json.IndexOf("}", start) - 1;
            providerNames.Add(json.Substring(start, (end - start)));
            //Debug.Log(json.Substring(start, (end - start)));
        }
        providersFound = true;
    }

    IEnumerator WaitForProviders (bool display)
    {
        while (!providersFound)
        {
            yield return null;
        }
        for (int i = 0; i < providerNames.Count; i++)
        {
            string url = "http://vm-hub.trafficmanager.net/Vhub/GetWorkingInstances/" + providerNames[i] + "/00000000-0000-0000-0000-000000000000/" + TimeFormat() + "/0/SecretKeyShouldbeLongerThan10";
            //Debug.Log("entered: " + providerNames[i]);
            UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbGET);
            req.downloadHandler = new DownloadHandlerBuffer();
            if (display)
            {
                StartCoroutine(MakeRequest(req, ParseAllClassifiersDisplay, true));
            }
            else
            {
                StartCoroutine(MakeRequest(req, ParseAllClassifiers, true));
            }
        }
    }
    void AllClassifiers (bool display)
    {
        mode = 2;
        prajnaMode = -1;
        modeBox.text = "Mode: Prajna";
        classifierNames = new List<string>();
        classifierIds = new List<string>();

        if (providerNames == null)
        {
            AllProviders();
            StartCoroutine(WaitForProviders(display));
        }
        else
        {
            for (int i = 0; i < providerNames.Count; i++)
            {
                string url = "http://vm-hub.trafficmanager.net/Vhub/GetWorkingInstances/" + providerNames[i] + "/00000000-0000-0000-0000-000000000000/" + TimeFormat() + "/0/SecretKeyShouldbeLongerThan10";
                //Debug.Log("entered: " + providerNames[i]);
                UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbGET);
                req.downloadHandler = new DownloadHandlerBuffer();
                if (display)
                {
                    StartCoroutine(MakeRequest(req, ParseAllClassifiersDisplay, true));
                }
                else
                {
                    StartCoroutine(MakeRequest(req, ParseAllClassifiers, true));
                }
            }
        }
    }

    void ParseAllClassifiers (string json)
    {
        int i = 0;

        while ((i = json.IndexOf("\"Name", i)) != -1)
        {
            int end = json.IndexOf(',', i);
            i += 8;
            classifierNames.Add(json.Substring(i, (end - i - 1)));
            i = json.IndexOf("ServiceID", i) + 12;
            end = json.IndexOf(',', i);
            classifierIds.Add(json.Substring(i, (end - i - 1)));
        }
    }

    void ParseAllClassifiersDisplay(string json)
    {
        classifiersFound++;
        int i = 0;

        while ((i = json.IndexOf("\"Name", i)) != -1)
        {
            int end = json.IndexOf(',', i);
            i += 8;
            classifierNames.Add(json.Substring(i, (end - i - 1)));
            i = json.IndexOf("ServiceID", i) + 12;
            end = json.IndexOf(',', i);
            classifierIds.Add(json.Substring(i, (end - i - 1)));
        }
        if (classifiersFound == providerNames.Count)
        {
            //Debug.Log("displaying");
            textBox.text = (String.Join("\n", classifierNames.ToArray()));
            classifiersFound = 0;
        }
    }


    Int64 TimeFormat()
    {
        Int64 ret = 0;
        DateTime st = new DateTime(1970, 1, 1);
        TimeSpan t = (DateTime.Now.ToUniversalTime() - st);
        ret = (Int64)(t.TotalMilliseconds + 0.5);
        return (ret * 10000) + 621355968000000000;
    }

    void ChooseClassifier (string name) // you can say classifier number (1 - n) or part of classifier name
    {
        name = name.Replace(" ", "").Trim();
        if (classifierNames == null)
        {
            AllClassifiers(false);
        }

        int num = StringToNum(name);

        if (num != -1 && num <= classifierNames.Count)
        {
            prajnaMode = num - 1; // 0 based indexing
            PrajnaHub();
            modeBox.text = classifierNames[prajnaMode];
            return;
        }

        for (int i = 0; i < classifierNames.Count; i++) 
        {
            if (classifierNames[i].Contains(name))
            {
                prajnaMode = i;
                PrajnaHub();
                modeBox.text = classifierNames[prajnaMode];
                return;
            }
        }

        textBox.text = "Not a valid classifier";
    }

    int StringToNum(string name)
    {
        if (name.Contains("one"))
        {
            name = "1";
        }
        bool number = true;
        foreach (char c in name)
        {
            if (!(c >= '0' && c <= '9'))
            {
                number = false;
            }
        }
        if (number)
        {
            int num = Int32.Parse(name);
            Debug.Log("number: " + num);
            return num;
        }
        return -1;
    }

    void AddPicture () // adds the taken picture for the person who has just been created
    {
        string url = "https://api.projectoxford.ai/face/v1.0/persongroups/" + groupId + "/persons/" + personId + "/persistedFaces";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.SetRequestHeader("Content-Type", "application/octet-stream");
        req.downloadHandler = new DownloadHandlerBuffer();
        req.uploadHandler = new UploadHandlerRaw(byteArray.ToArray());
        StartCoroutine(MakeRequest(req, ParseAddPicture, true));
    }

    void ParseAddPicture (string json)
    {
        textBox.text = "Successfully added " + dictationText + "!";
        TrainGroup();
    }

    void TrainGroup () // trains the person group after adding new member
    {
        string url = "https://api.projectoxford.ai/face/v1.0/persongroups/" + groupId + "/train";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
        req.SetRequestHeader("Ocp-Apim-Subscription-Key", keyFace);
        req.downloadHandler = new DownloadHandlerBuffer();
        StartCoroutine(MakeRequest(req, null, false));
        newFace = false;
    }

    void ParseFace(string json) 
    {
        var parsed = JSON.Parse(json);
        int elements = SubstringNumber(json, "faceId");
        StringBuilder ret = new StringBuilder();
        if (elements > 0)
        {
            faceId = parsed[0]["faceId"].Value;
            for (int i = 0; i < elements; i++)
            {
                ret.Append(string.Format("Age: {0}, Gender: {1} \n", parsed[i]["faceAttributes"]["age"].Value, parsed[i]["faceAttributes"]["gender"].Value));
            }
            textBox.text = ret.ToString();
            //Debug.Log("faceID: " + faceId);
            FaceIdentify();
        }
        else
        {
            ret.Append("No faces");
            textBox.text = ret.ToString();
        }
    }

    int SubstringNumber(string json, string substring)
    {
        int count = 0;
        int i = 0;
        while ((i = json.IndexOf(substring, i)) != -1)
        {
            i += substring.Length;
            count++;
        }
        return count;
    }

    void ParseDescribe (string json)
    {
        int start = json.IndexOf("text\":\"") + 7;
        int end = json.IndexOf("confi") - 3;
        textBox.text = json.Substring(start, (end - start));
    }

    public void ChangeMode ()
    {
        newFace = false;

        switch (mode)
        {
            case 0:
                modeBox.text = "Mode: Caption";
                break;
            case 1:
                modeBox.text = "Mode: Faces";
                break;
            case 2:
                modeBox.text = "Mode: Prajna";
                break;
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
        //Debug.Log(samplingRate);

        dictationRecognizer = new DictationRecognizer();
        dictationRecognizer.DictationResult += DictationRecognizer_DictationResult;
        dictationRecognizer.DictationComplete += DictationRecognizer_DictationComplete;

        dictationText = "";
        dictationRecognizer.Start();
        //Debug.Log("started recording");
        modeBox.color = Color.cyan;
        modeBox.text = "Listening";
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
        //Debug.Log("finished result");
    }

    private void DictationRecognizer_DictationComplete(DictationCompletionCause cause)
    {
        modeBox.color = Color.red;
        PhraseRecognitionSystem.Restart();

        if (recordingMethod == 0)
        {
            AddPerson(dictationText);
        }
        else if (recordingMethod == 1)
        {
            ChooseClassifier(dictationText);
        }
    }

    IEnumerator Stop ()
    {
        while (startedPhoto)
        {
            yield return null;
        }
        StopAllCoroutines();
    }
}