using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System;

[Serializable]
public class GetPersonClass
{
    public string personId;
    public List<string> persistedFaceIds = new List<string>();
    public string name;
}
