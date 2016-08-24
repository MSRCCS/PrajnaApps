using UnityEngine;
using System.Collections;
using UnityEngine.UI;

public class PanelText : MonoBehaviour
{
    public int prajnaMode = -1; 
    public Clicker.Modes mode;
    public int id;

    void Start()
    {
        Text t = this.gameObject.GetComponent<Text>();
        t.color = Color.blue;
    }
    void Update()
    {
        Text t = this.gameObject.GetComponent<Text>();

        if (Clicker.mode == (int) this.mode && Clicker.prajnaMode == this.prajnaMode)
        {
            t.color = Color.cyan;
        }
        else if (CursorManager.idHighlighted == this.id)
        {
            t.color = Color.gray;
        }
        else
        {
            t.color = Color.blue;
        }
    }
}
