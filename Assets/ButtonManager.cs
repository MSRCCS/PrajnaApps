using UnityEngine;
using System.Collections;
using UnityEngine.UI;
using System.Collections.Generic;

public class ButtonManager : MonoBehaviour
{
    public int id;

    public List<GameObject> displayObjects;
    public List<GameObject> menuObjects;

    public GameObject displayCanvas;
    public GameObject cursor;
    public GameObject classifiersMenu;

	// Use this for initialization
	void Start ()
    {
        Text t = this.gameObject.GetComponent<Text>();
        t.color = Color.green;
	}
	
	// Update is called once per frame
	void Update ()
    {
        Text t = this.gameObject.GetComponent<Text>();
        if (GazeManager.highlightedButtonId == this.id || CursorManager.idHighlighedButton == this.id)
        {
            t.color = Color.gray;
        }
        else
        {
            t.color = Color.green;
        }
	}

    IEnumerator ButtonPress (bool display)
    {
        Debug.Log("in button press");

        while (Clicker.startedPhoto)
        {
            yield return null;
            Debug.Log("started photo wait");
        }

        Clicker.startedPhoto = false;
        Clicker.startedRoutine = false;
        Clicker.newFace = false;

        if (!display)
        {
            displayCanvas.GetComponent<GazeManager>().recognizer.StopCapturingGestures();

            foreach (GameObject g in displayObjects)
            {
                g.SetActive(display);
            }

            foreach (GameObject g in menuObjects)
            {
                g.SetActive(!display);
            }

            if (cursor.GetComponent<CursorManager>().recognizer != null)
            {
                cursor.GetComponent<CursorManager>().recognizer.StartCapturingGestures();
            }

            if (classifiersMenu.activeInHierarchy)
            {
                Debug.Log("recalculating classifiers");
                classifiersMenu.GetComponent<MenuManager>().BroadcastMessage("DisplayClassifiers");
            }
        }
        else
        {
            cursor.GetComponent<CursorManager>().recognizer.StopCapturingGestures();

            foreach (GameObject g in displayObjects)
            {
                g.SetActive(display);
            }

            foreach (GameObject g in menuObjects)
            {
                g.SetActive(!display);
            }

            if (displayCanvas.GetComponent<GazeManager>().recognizer != null)
            {
                displayCanvas.GetComponent<GazeManager>().recognizer.StartCapturingGestures();
            }
        }
        Debug.Log("finished " + display);
    }
}
