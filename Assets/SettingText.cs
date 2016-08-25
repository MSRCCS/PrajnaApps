using UnityEngine;
using System.Collections;
using UnityEngine.UI;
using System;

public class SettingText : MonoBehaviour
{
    public int id;
    public int settingType;
    public int settingResponse;

    public Text thresholdText;

    // Use this for initialization
    void Start()
    {
        Text t = this.gameObject.GetComponent<Text>();
        t.color = Color.blue;
    }

    // Update is called once per frame
    void Update()
    {
        Text t = this.gameObject.GetComponent<Text>();
        if (settingType == 0)
        {
            if (Clicker.displayImage && settingResponse == 1)
            {
                t.color = Color.cyan;
            }
            else if (!Clicker.displayImage && settingResponse == 0)
            {
                t.color = Color.cyan;
            }
            else if (CursorManager.idHighlightedSetting == this.id)
            {
                t.color = Color.gray;
            }
            else
            {
                t.color = Color.blue;
            }
        }
        else if (settingType == 1)
        {
            if (CursorManager.idHighlightedSetting == this.id)
            {
                t.color = Color.gray;
            }
            else
            {
                t.color = Color.blue;
            }
        }

        if (settingType == 1 && settingResponse == 1)
        {
            thresholdText.text = ("Confidence Threshold: " + Clicker.confidenceThreshold);
        }

    }

    void SettingChange()
    {
        if (settingType == 0 && settingResponse == 0)
        {
            Clicker.displayImage = false;
        }
        else if (settingType == 0)
        {
            Clicker.displayImage = true;
        }
        else if (settingResponse == 0)
        {
            ChangeThresh(false);
        }
        else
        {
            ChangeThresh(true);
        }
    }

    void ChangeThresh (bool up)
    {
        if (up && Clicker.confidenceThreshold <= 0.9f)
        {
            Clicker.confidenceThreshold = (float) Math.Round(Clicker.confidenceThreshold + 0.1f, 1);
        }

        else if (!up && Clicker.confidenceThreshold >= 0.1f)
        {
            Clicker.confidenceThreshold = (float) Math.Round(Clicker.confidenceThreshold - 0.1f, 1);
        }
    }
  
}
