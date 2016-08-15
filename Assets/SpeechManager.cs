﻿using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Windows.Speech;

public class SpeechManager : MonoBehaviour
{
    KeywordRecognizer keywordRecognizer = null;
    Dictionary<string, System.Action> keywords = new Dictionary<string, System.Action>();

    // Use this for initialization
    void Start()
    {
        keywords.Add("Caption", () =>
        {
            Debug.Log("command caption");
            //this.GetComponent<Clicker>().Captions();
            if (!Clicker.caption)
            {
                this.BroadcastMessage("ChangeMode");
            }
        });

        keywords.Add("Face", () =>
        {
            Debug.Log("command face");
            //this.GetComponent<Clicker>().Faces();
            if (Clicker.caption)
            {
                this.BroadcastMessage("ChangeMode");
            }
        });

        keywords.Add("Add Person", () =>
        {
            Debug.Log("command add");
            if (!Clicker.caption && Clicker.newFace)
            {
                this.BroadcastMessage("StartRecording");
            }
        });

        // Tell the KeywordRecognizer about our keywords.
        keywordRecognizer = new KeywordRecognizer(keywords.Keys.ToArray());

        // Register a callback for the KeywordRecognizer and start recognizing!
        keywordRecognizer.OnPhraseRecognized += KeywordRecognizer_OnPhraseRecognized;
        keywordRecognizer.Start();
    }

    private void KeywordRecognizer_OnPhraseRecognized(PhraseRecognizedEventArgs args)
    {
        System.Action keywordAction;
        if (keywords.TryGetValue(args.text, out keywordAction))
        {
            keywordAction.Invoke();
        }
    }
}