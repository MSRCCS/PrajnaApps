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
    public GameObject textPrefab;
    public VerticalLayoutGroup layoutGroup;
    public Canvas world;
    public GameObject panel;
    public GameObject display;

    public enum Modes {Caption, Face, Prajna};

    int iter = 0; // timing for calling PhotoCapture
    public Text textBox; // main display textbox
    public Text modeBox; // textbox on top right that shows mode
    public Image image; // displays captured image on the screen 

    public static int mode = (int) Modes.Caption; // 0 = caption, 1 = faces, 2 = prajna
    public static int prajnaMode = -1; // -1 = none, 0-n = classifier within prajna
    public static bool displayImage = false; // true = show picture, false = dont show
    public static float confidenceThreshold = 0.0f; // minimum confidence to change caption

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

    public static List<string> providerNames = null; // names of prajna providers
    public static List<string> classifierNames = null; // names of prajna classifiers
    public static List<string> classifierIds = null; // IDs of prajna classifiers
    public static int providersEntered = 0; // used to ensure all classifiers parsed before displaying
    public static bool providersFound = false; // used to ensure all classifiers parsed before finding classifiers

    public static int recordingMethod; // 0 = face name, 1 = prajna classifier name
    public static bool switcher = false;

    void Start()
    {
        StartCoroutine(CapturePhoto());
    }

    void Update()
    {
        if (!startedPhoto && !startedRoutine && !newFace)
        {
            iter++;
            if (((GazeManager.changedGaze && iter > 40) || (iter > 350)) && !(classifierNames != null && mode == (int) Modes.Prajna  && prajnaMode == -1)) // passed distance or time threshold and won't redisplay all prajna classifiers
            {
                //world.SetActive(true); // turns on and off
                //world.transform.position = new Vector3(Camera.main.transform.forward.x * 50, Camera.main.transform.forward.y * 50, Camera.main.transform.position.z + 50); // not moving with camera
                //degrees.transform.LookAt(Camera.main.transform);
                //Debug.Log("cam: " + Camera.main.transform.position.x + " " + Camera.main.transform.position.y + " " + Camera.main.transform.position.z);
                GazeManager.changedGaze = false;
                GazeManager.totalDiff = 0;
                iter = 0;
                StartCoroutine(CapturePhoto());
            }
        }
    }

    private IEnumerator CapturePhoto()
    {
        //Debug.Log("head: " + GazeManager.headPosition.x + " " + GazeManager.headPosition.y + " " + GazeManager.headPosition.z);
        //Debug.Log("world: " + world.transform.position.x + " " + world.transform.position.y + " " + world.transform.position.z);
        //Debug.Log("panel: " + panel.transform.position.x + " " + panel.transform.position.y + " " + panel.transform.position.z);
        //Debug.Log("image: " + degrees.transform.position.x + " " + degrees.transform.position.y + " " + degrees.transform.position.z);
        startedPhoto = true; // won't take another photo while one is already being taken

        Resolution res = PhotoCapture.SupportedResolutions.OrderBy((r) => r.width * r.height).First(); // sorts resolutions in asending order - this takes lowest
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
        cameraParameters.pixelFormat = CapturePixelFormat.JPEG; // need JPEG for sending to APIs
        //Debug.LogFormat("Starting photo mode with {0}x{1}", cameraParameters.cameraResolutionWidth, cameraParameters.cameraResolutionHeight);
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
            //Debug.Log("Success photo");
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
        ImagePanel();

        if (mode == (int) Modes.Caption)
        {
            Describe();
        }
        else if (mode == (int) Modes.Face)
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
        StopCoroutine("CapturePhoto"); // safely end coroutine
    }

    /* request method for all API calls - operates asynchronously*/
    IEnumerator MakeRequest(UnityWebRequest req, Action<string> act, bool actionToDo) // takes in request, method to call after request is sent (to parse results), whether a method needs to be called after
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

    void ImagePanel() // displays captured image on panel on hololens (can turn this on/off by adjusting alpha level of the image in Unity editor)
    {
        Texture2D texture = new Texture2D(2, 2);
        texture.LoadImage(byteArray.ToArray());
        //GC.Collect();
        image.sprite = Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), new Vector2(0, 0));

        //Debug.Log("posted image sprite");
    }

    void Describe() // caption to textbox
    {
        mode = (int) Modes.Caption;
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
        mode = (int) Modes.Face;
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
        }
        else // face is part of person group
        {
            string id = JSON.Parse(json)[0]["candidates"][0]["personId"].Value;
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
        mode = (int) Modes.Prajna;
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
        mode = (int) Modes.Prajna;
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
            Debug.Log(json.Substring(start, (end - start)));
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
        mode = (int) Modes.Prajna;
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
        providersEntered++;
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
        providersEntered++;
        int i = 0;

        while ((i = json.IndexOf("\"Name", i)) != -1)
        {
            int end = json.IndexOf(',', i);
            i += 8;
            string name = json.Substring(i, (end - i - 1));
            classifierNames.Add(json.Substring(i, (end - i - 1)));
            i = json.IndexOf("ServiceID", i) + 12;
            end = json.IndexOf(',', i);
            classifierIds.Add(json.Substring(i, (end - i - 1)));
        }
        if (providersEntered == providerNames.Count)
        {
            //Debug.Log("displaying");
            textBox.text = (String.Join("\n", classifierNames.ToArray()));
            providersEntered = 0;
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
        if (name == null || name.Length == 0)
        {
            return -1;
        }
        name.Trim();
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
            Debug.Log("number: " + name);
            int num = Int32.Parse(name);
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

        StartCoroutine(WaitForPhoto());
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

    IEnumerator WaitForPhoto()
    {
        while (startedPhoto || startedRoutine)
        {
            yield return null;
        }
        StartCoroutine(CapturePhoto());
    }

    void TestMenu ()
    {
        if (switcher)
        {
            panel.SetActive(true);
            display.SetActive(false);
            world.renderMode = RenderMode.WorldSpace;
            world.worldCamera = Camera.main;
            switcher = !switcher;
        }
        else
        {
            panel.SetActive(false);
            display.SetActive(true);
            world.renderMode = RenderMode.ScreenSpaceCamera;
            world.worldCamera = Camera.main;
            switcher = !switcher;
        }
    }
}