using UnityEngine;
using UnityEngine.VR.WSA.Input;

public class GazeManager : MonoBehaviour
{
    public static GazeManager Instance { get; private set; }

    // Represents the hologram that is currently being gazed at.
    public GameObject FocusedObject { get; private set; }

    public static Vector3 headPosition;
    public static Vector3 previousPosition;
    public static bool changedGaze = false;
    public static float diff = 0;
    public static float totalDiff = 0;

    private int iter = 0;

    GestureRecognizer recognizer;

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
            Debug.Log("Tapped object");
            this.BroadcastMessage("ChangeMode");
        };
        recognizer.StartCapturingGestures();
    }

    // Update is called once per frame
    void Update()
    {
        iter++;
        // Figure out which hologram is focused this frame.
        GameObject oldFocusObject = FocusedObject;

        // Do a raycast into the world based on the user's
        // head position and orientation.
        if (iter == 40)
        {
            previousPosition = headPosition;
        }

        headPosition = Camera.main.transform.position;

        if (iter == 40)
        {
            iter = 0;
            diff = Mathf.Pow((previousPosition.x - headPosition.x), 2) + Mathf.Pow((previousPosition.y - headPosition.y), 2);
            totalDiff += diff;

            if (totalDiff > 3 * Mathf.Pow(10, (-7)))
            {
                changedGaze = true;
            }
        }
        var gazeDirection = Camera.main.transform.forward;

        RaycastHit hitInfo;
        if (Physics.Raycast(headPosition, gazeDirection, out hitInfo))
        {
            // If the raycast hit a hologram, use that as the focused object.
            FocusedObject = hitInfo.collider.gameObject;
        }
        else
        {
            // If the raycast did not hit a hologram, clear the focused object.
            FocusedObject = null;
        }

        // If the focused object changed this frame,
        // start detecting fresh gestures again.
        if (FocusedObject != oldFocusObject)
        {
            recognizer.CancelGestures();
            recognizer.StartCapturingGestures();
        }
    }
}