using UnityEngine;
using System.Collections;
using UnityEngine.UI;
using System.Collections.Generic;
using System;
using UnityEngine.Networking;

public class MenuManager : MonoBehaviour
{

    public GameObject textPrefab;
    public VerticalLayoutGroup layoutGroup;

    private static List<string> providerNames = null; // names of prajna providers
    private static List<string> classifierNames = null; // names of prajna classifiers
    private static List<string> classifierIds = null; // IDs of prajna classifiers
    private static int providersEntered = 0; // used to ensure all classifiers parsed before displaying
    private static bool providersFound = false; // used to ensure all classifiers parsed before finding classifiers

    void Start ()
    {
        //DisplayClassifiers();
	}
	
	// Update is called once per frame
	void Update ()
    {
	
	}

    void DisplayClassifiers ()
    {
        var children = new List<GameObject>();
        foreach (Transform child in layoutGroup.transform)
        {
            children.Add(child.gameObject);
        }
        if (children.Count >= 1)
        {
            children.ForEach(child => Destroy(child));
        }

        MenuAdd("1. Caption", Clicker.Modes.Caption, -1, 1);
        MenuAdd("2. Face", Clicker.Modes.Face, -1, 2);
        MenuAdd("3. PrajnaHub", Clicker.Modes.Prajna, -1, 3);
        AllClassifiers(true); 
    }

    public void MenuAdd (string text, Clicker.Modes type, int prajnaMode, int id)
    {
        GameObject gameObject = (GameObject)Instantiate(textPrefab);
        Text textbox = gameObject.GetComponent<Text>();
        textbox.text = text;
        gameObject.transform.localScale = new Vector3(1, 1, 1);
        gameObject.transform.SetParent(layoutGroup.transform, false);
        gameObject.GetComponent<PanelText>().prajnaMode = prajnaMode;
        gameObject.GetComponent<PanelText>().mode = type;
        gameObject.GetComponent<PanelText>().id = id;
    }

    void AllProviders()
    {
        providersFound = false;
        providerNames = new List<string>();
        string url = "http://vm-hub.trafficmanager.net/Vhub/GetActiveProviders/00000000-0000-0000-0000-000000000000/" + TimeFormat() + "/0/SecretKeyShouldbeLongerThan10";
        UnityWebRequest req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbGET);
        req.downloadHandler = new DownloadHandlerBuffer();
        StartCoroutine(MakeRequest(req, ParseAllProviders, true));
    }

    void ParseAllProviders(string json)
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

    IEnumerator WaitForProviders(bool display)
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

    void AllClassifiers(bool display)
    {
        Clicker.classifierNames = new List<string>();
        Clicker.classifierIds = new List<string>();
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

    void ParseAllClassifiers(string json)
    {
        int i = 0;
        providersEntered++;
        while ((i = json.IndexOf("\"Name", i)) != -1)
        {
            int end = json.IndexOf(',', i);
            i += 8;
            classifierNames.Add(json.Substring(i, (end - i - 1)));
            Clicker.classifierNames.Add(json.Substring(i, (end - i - 1)));
            i = json.IndexOf("ServiceID", i) + 12;
            end = json.IndexOf(',', i);
            classifierIds.Add(json.Substring(i, (end - i - 1)));
            Clicker.classifierIds.Add(json.Substring(i, (end - i - 1)));
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
            classifierNames.Add(json.Substring(i, (end - i - 1)));
            Clicker.classifierNames.Add(json.Substring(i, (end - i - 1)));
            i = json.IndexOf("ServiceID", i) + 12;
            end = json.IndexOf(',', i);
            classifierIds.Add(json.Substring(i, (end - i - 1)));
            Clicker.classifierIds.Add(json.Substring(i, (end - i - 1)));
        }
        if (providersEntered == providerNames.Count)
        {
            Debug.Log("displaying");
            for (int k = 0; k < classifierNames.Count; k++)
            {
                MenuAdd("\t" + (4 + k) + ". " + classifierNames[k], Clicker.Modes.Prajna, k, (4+k));
            }
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

    IEnumerator MakeRequest(UnityWebRequest req, Action<string> act, bool actionToDo) // takes in request, method to call after request is sent (to parse results), whether a method needs to be called after
    {
        ////Debug.Log("making request");
        yield return req.Send();

        if (req.isError)
        {
            Debug.Log("request error");
            Debug.Log(req.error);
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
        StopCoroutine("MakeRequest");
    }
}
