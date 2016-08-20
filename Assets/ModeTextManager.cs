using UnityEngine;
using System.Collections;
using UnityEngine.UI;

public class ModeTextManager : MonoBehaviour
{
	void Start ()
    {
        this.gameObject.GetComponent<Text>().text = "Mode: Caption";
	}
	
	
	void Update ()
    {
        Text t = this.gameObject.GetComponent<Text>();
	    switch (Clicker.mode)
        {
            case (0):
                t.text = "Mode: Caption";
                break;
            case (1):
                t.text = "Mode: Face";
                break;
            case (2):
                if (Clicker.prajnaMode == -1)
                {
                    t.text = "Mode: Prajna Hub";
                }
                else
                {
                    t.text = "Mode: " + Clicker.classifierNames[Clicker.prajnaMode];
                }
                break;
        }
	}
}
