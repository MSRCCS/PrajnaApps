using UnityEngine;
using System.Collections;
using UnityEngine.VR.WSA.Input;
using UnityEngine.UI;

public class SelectionMenu : MonoBehaviour
{
    public int mode;
    public int id;

    void Start()
    {
        Text t = this.gameObject.GetComponent<Text>();
        t.color = Color.red;
    }
    void Update()
    {
        Text t = this.gameObject.GetComponent<Text>();

        if (CursorManager.menuMode == mode)
        {
            t.color = Color.cyan;
        }
        else if (CursorManager.idHighlightedMenu == this.id)
        {
            t.color = Color.gray;
        }
        else
        {
            t.color = Color.red;
        }
    }
}
