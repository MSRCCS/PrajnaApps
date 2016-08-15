using UnityEngine;
using System.Collections;
using UnityEngine.UI;

public class Texter : MonoBehaviour {

    // Use this for initialization
    public Text text;
    int it = 0;

	void Start ()
    {
        text.text = "text 1";
	}

    void Update()
    {
        it++;
        if (it > 200 && it % 200 == 0)
        {
            text.text = it.ToString();
        }
    }
	
}
