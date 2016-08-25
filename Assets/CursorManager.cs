using UnityEngine;
using UnityEngine.UI;
using UnityEngine.VR.WSA.Input;

public class CursorManager : MonoBehaviour
{

    public GestureRecognizer recognizer;
    public bool hit = false;
    GameObject hitter;

    public static int idHighlighted = 0;
    public static int idHighlightedMenu = 0;
    public static int idHighlightedSetting = 0;
    public static int idHighlighedButton = 0;
    public static int idHighlightedTermButton = 0;

    public static int menuMode = 0;

    public GameObject settingsMenu;
    public GameObject classifiersMenu;
    public GameObject tutorialMenu;

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
                    case ("Button"):
                        Debug.Log("button");
                        if (hitter.GetComponent<ButtonManager>().id == 2)
                        {
                            ButtonTag();
                        }
                        break;
                    case ("TermButton"):
                        Debug.Log("term button");
                        TermButtonTag();
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
                    idHighlighedButton = 0;
                    break;
                case ("SelectionMenu"):
                    idHighlightedMenu = hitter.GetComponent<SelectionMenu>().id;
                    idHighlighted = 0;
                    idHighlightedSetting = 0;
                    idHighlighedButton = 0;
                    break;
                case ("Setting"):
                    idHighlightedSetting = hitter.GetComponent<SettingText>().id;
                    idHighlighted = 0;
                    idHighlightedMenu = 0;
                    idHighlighedButton = 0;
                    break;
                case ("Button"):
                    idHighlighedButton = hitter.GetComponent<ButtonManager>().id;
                    idHighlighted = 0;
                    idHighlightedMenu = 0;
                    idHighlightedSetting = 0;
                    break;
                case ("TermButton"):
                    idHighlightedTermButton = hitter.GetComponent<TermButton>().id;
                    idHighlighted = 0;
                    idHighlightedMenu = 0;
                    idHighlightedSetting = 0;
                    idHighlighedButton = 0;
                    break;
             }
        }
        else
        {
            idHighlighted = 0;
            idHighlightedMenu = 0;
            idHighlightedSetting = 0;
            idHighlighedButton = 0;
            idHighlightedTermButton = 0;
        }
    }

    void ClassifierTag()
    {
        Clicker.mode = (int)hitter.GetComponent<PanelText>().mode;
        Clicker.prajnaMode = hitter.GetComponent<PanelText>().prajnaMode;
    }

    void SelectionMenuTag ()
    {
        int newMode = 0;
        if (hitter.GetComponent<Text>().text.Contains("Settings"))
        {
            newMode = 1;
        }
        else if (hitter.GetComponent<Text>().text.Contains("Tutorial"))
        {
            newMode = 2;
        }

        if (newMode != menuMode)
        {
            switch (newMode)
            {
                case 0:
                    settingsMenu.SetActive(false);
                    tutorialMenu.SetActive(false);
                    classifiersMenu.SetActive(true);
                    classifiersMenu.BroadcastMessage("DisplayClassifiers");
                    break;
                case 1:
                    classifiersMenu.SetActive(false);
                    tutorialMenu.SetActive(false);
                    settingsMenu.SetActive(true);
                    break;
                case 2:
                    classifiersMenu.SetActive(false);
                    settingsMenu.SetActive(false);
                    tutorialMenu.SetActive(true);
                    break;
            }
            menuMode = newMode;
        }
    }

    void SettingTag ()
    {
        hitter.BroadcastMessage("SettingChange");
    }

    void ButtonTag ()
    {
        Debug.Log("calling button press cursor");
        hitter.BroadcastMessage("ButtonPress", true);
    }

    void TermButtonTag ()
    {
        hitter.BroadcastMessage("ButtonPress");
    }
}