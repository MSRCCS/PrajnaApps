using UnityEngine;
using System.Collections;
using UnityEngine.UI;

public class TermButton : MonoBehaviour {

    public int id;
    public bool accept;

    public GameObject parent;
    public GameObject cursor;
    public GameObject intro;

    public GameObject declineMessage;


	void Start ()
    {
        Text t = this.gameObject.GetComponent<Text>();
	    if (this.accept)
        {
            t.color = Color.green;
        }

        else
        {
            t.color = Color.red;
        }
	}
	
	// Update is called once per frame
	void Update ()
    {
        Text t = this.gameObject.GetComponent<Text>();
        if (CursorManager.idHighlightedTermButton == this.id)
        {
            t.fontStyle = FontStyle.BoldAndItalic;
        }
        else
        {
            t.fontStyle = FontStyle.Normal;
        }
    }

    void ButtonPress ()
    {
        if (this.accept)
        {
            cursor.SetActive(false);
            parent.SetActive(true);
            intro.SetActive(false);
        }
        else
        {
            declineMessage.SetActive(true);
        }
    }


}
