using UnityEngine;
using UnityEngine.UI;
using UnityEngine.VR.WSA.Input;

public class CursorManager : MonoBehaviour
{

    GestureRecognizer recognizer;
    public bool hit = false;
    GameObject hitter;
    public static int idHighlighted = 0;
    public static int idHighlightedMenu = 0;
    public static int idHighlightedSetting = 0;
    public static int menuMode = 0;

    public GameObject settingsMenu;
    public GameObject classifiersMenu;
    // Use this for initialization
    void Start()
    {
        recognizer = new GestureRecognizer();
        recognizer.TappedEvent += (source, tapCount, ray) =>
        {
            if (hit)
            {
                switch (hitter.tag)
                {
                    case ("Classifier"):
                        Debug.Log("classifier");
                        ClassifierTag();
                        break;
                    case ("SelectionMenu"):
                        Debug.Log("selectionmenu");
                        SelectionMenuTag();
                        break;
                    case ("Setting"):
                        Debug.Log("setting");
                        SettingTag();
                        break;
                }
            }
        };
        recognizer.StartCapturingGestures();
    }

    // Update is called once per frame
    void Update()
    {
        // Do a raycast into the world based on the user's
        // head position and orientation.
        var headPosition = Camera.main.transform.position;
        var gazeDirection = Camera.main.transform.forward;

        RaycastHit hitInfo;

        if (!Clicker.switcher)
        {
            this.transform.position = new Vector3(Camera.main.transform.forward.x * 50, Camera.main.transform.forward.y * 50, Camera.main.transform.position.z + 50);
            hit = Physics.Raycast(headPosition, gazeDirection, out hitInfo);

            if (hit)
            {
                hitter = hitInfo.transform.gameObject;
                switch (hitter.tag)
                {
                    case ("Classifier"):
                        idHighlighted = hitter.GetComponent<PanelText>().id;
                        idHighlightedMenu = 0;
                        idHighlightedSetting = 0;
                        break;
                    case ("SelectionMenu"):
                        idHighlightedMenu = hitter.GetComponent<SelectionMenu>().id;
                        idHighlighted = 0;
                        idHighlightedSetting = 0;
                        break;
                    case ("Setting"):
                        idHighlightedSetting = hitter.GetComponent<SettingText>().id;
                        idHighlighted = 0;
                        idHighlightedMenu = 0;
                        break;
                }
            }
            else
            {
                idHighlighted = 0;
            }

        }
        else
        {
            idHighlighted = 0;
        }
    }

    void ClassifierTag()
    {
        Clicker.mode = (int)hitter.GetComponent<PanelText>().mode;
        Clicker.prajnaMode = hitter.GetComponent<PanelText>().prajnaMode;
    }

    void SelectionMenuTag ()
    {
        int newMode = 1;
        if (hitter.GetComponent<Text>().text.Contains("Classifiers"))
        {
            newMode = 0;
        }

        if (newMode != menuMode && newMode == 0)
        {
            settingsMenu.SetActive(false);
            classifiersMenu.SetActive(true);
            menuMode = newMode;
        }
        else if (newMode != menuMode && newMode == 1)
        {
            classifiersMenu.SetActive(false);
            settingsMenu.SetActive(true);
            menuMode = newMode;
        }
    }

    void SettingTag ()
    {
        hitter.BroadcastMessage("SettingChange");
    }
}