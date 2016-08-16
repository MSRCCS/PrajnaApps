using System.Collections.Generic;
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
            Clicker.mode = 0;
            this.BroadcastMessage("ChangeMode");
        });

        keywords.Add("Face", () =>
        {
            Debug.Log("command face");
            Clicker.mode = 1;
            this.BroadcastMessage("ChangeMode", 1);
        });

        keywords.Add("Add Person", () =>
        {
            Debug.Log("command add");
            if (Clicker.mode == 1 && Clicker.newFace)
            {
                Clicker.recordingMethod = 0;
                this.BroadcastMessage("StartRecording");
            }
        });

        keywords.Add("All Classifiers", () =>
        {
            Debug.Log("command all classifiers");
            Clicker.mode = 2;
            Clicker.prajnaMode = -1;
            this.BroadcastMessage("ChangeMode");
        });

        keywords.Add("Choose Classifier", () =>
        {
            Debug.Log("command choose classifier");
            Clicker.recordingMethod = 1;
            this.BroadcastMessage("StartRecording");
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