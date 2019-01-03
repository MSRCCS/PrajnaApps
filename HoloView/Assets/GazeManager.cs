using UnityEngine;
using UnityEngine.VR.WSA.Input;

public class GazeManager : MonoBehaviour
{
    public static GazeManager Instance { get; private set; }

    // Represents the hologram that is currently being gazed at.
    public GameObject FocusedObject { get; private set; }

    public static Vector3 headPosition;
    public static Vector3 gazeDirection;
    public static Vector3 previousPosition;
    public static bool changedGaze = false;
    public static float diff = 0;
    public static float totalDiff = 0;
    public static int highlightedButtonId = 0;

    public static int iter = 0;

    public GestureRecognizer recognizer;

    // Use this for initialization
    void Start()
    {
        previousPosition = new Vector3(0, 0, 0);
        headPosition = new Vector3(0, 0, 0);
        Instance = this;

        // Set up a GestureRecognizer to detect Select gestures.
        recognizer = new GestureRecognizer();
        recognizer.TappedEvent += (source, tapCount, ray) =>
        {
            Debug.Log("Tapped object gaze");
            if (FocusedObject == null)
            {
                Clicker.mode = (Clicker.mode + 1) % 3; // switches to next mode (0, 1, 2)
                this.BroadcastMessage("ChangeMode");
            }
            else if (FocusedObject.tag.Equals("Button") && FocusedObject.GetComponent<ButtonManager>().id == 1)
            {
                Debug.Log("calling button press gaze");
                FocusedObject.BroadcastMessage("ButtonPress", false);
            }
        };
        recognizer.StartCapturingGestures();
    }

    // Update is called once per frame
    void Update()
    {
       
        iter++;

        if (iter == 40)
        {
            previousPosition = gazeDirection;
        }

        headPosition = Camera.main.transform.position;
        gazeDirection = Camera.main.transform.forward;

        if (iter == 40)
        {
            iter = 0;
            diff = Mathf.Pow((previousPosition.x - gazeDirection.x), 2) + Mathf.Pow((previousPosition.y - gazeDirection.y), 2);
            totalDiff += diff;

            if (totalDiff > 3 * Mathf.Pow(10, (-5))) // distance threshold for trigger another API call 
            {
                changedGaze = true;
            }
        }

        RaycastHit hitInfo;
        if (Physics.Raycast(headPosition, gazeDirection, out hitInfo))
        {
            FocusedObject = hitInfo.transform.gameObject;
            highlightedButtonId = FocusedObject.GetComponent<ButtonManager>().id;
        }
        else
        {
            highlightedButtonId = 0;
            FocusedObject = null;
        }
    }
}