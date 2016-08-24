using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Windows.Speech;

public class SpeechManager : MonoBehaviour
{
    KeywordRecognizer keywordRecognizer = null;
    Dictionary<string, System.Action> keywords = new Dictionary<string, System.Action>();

    public bool onCanvas = true;

    public GameObject canvas;
    public GameObject worldCanvas;
    public GameObject cursor;

    // Use this for initialization
    void Start()
    {
        keywords.Add("Caption", () =>
        {
            Debug.Log("command caption");
            Clicker.mode = (int) Clicker.Modes.Caption;
            canvas.BroadcastMessage("ChangeMode");
        });

        keywords.Add("Face", () =>
        {
            Debug.Log("command face");
            Clicker.mode = (int) Clicker.Modes.Face;
            canvas.BroadcastMessage("ChangeMode", 1);
        });

        keywords.Add("Add Person", () =>
        {
            Debug.Log("command add");
            if (Clicker.mode == (int) Clicker.Modes.Face && Clicker.newFace)
            {
                Clicker.recordingMethod = 0;
                canvas.BroadcastMessage("StartRecording");
            }
        });

        keywords.Add("Prajna", () =>
        {
            Debug.Log("command prajna");
            Clicker.mode = (int)Clicker.Modes.Prajna;
            canvas.BroadcastMessage("ChangeMode");
        });

        keywords.Add("Show", () =>
        {
            Debug.Log("command show (all classifiers)");
            Clicker.mode = (int)Clicker.Modes.Prajna;
            Clicker.prajnaMode = -1;
            canvas.BroadcastMessage("ChangeMode");
        });

        keywords.Add("All Classifiers", () =>
        {
            Debug.Log("command all classifiers");
            Clicker.mode = (int) Clicker.Modes.Prajna;
            Clicker.prajnaMode = -1;
            canvas.BroadcastMessage("ChangeMode");
        });

        keywords.Add("Choose", () =>
        {
            Debug.Log("command choose (classifier)");
            Clicker.recordingMethod = 1;
            canvas.BroadcastMessage("StartRecording");
        });

        keywords.Add("Choose Classifier", () =>
        {
            Debug.Log("command choose classifier");
            Clicker.recordingMethod = 1;
            canvas.BroadcastMessage("StartRecording");
        });

        keywords.Add("Menu", () =>
        {
            Debug.Log("command menu");

            if (onCanvas)
            {
                canvas.SetActive(false);
                cursor.SetActive(true);
                worldCanvas.SetActive(true);
                onCanvas = !onCanvas;
            }
        });

        keywords.Add("Exit", () =>
        {
            Debug.Log("command exit");

            if (!onCanvas)
            {
                worldCanvas.SetActive(false);
                cursor.SetActive(false);
                canvas.SetActive(true);
                onCanvas = !onCanvas;
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