using UnityEngine;
using System.Collections;
using System;
using System.Collections.Generic;

[Serializable]
public class PrajnaHubClass
{
    public string Description;
    //public List<string> AuxData = new List<string>();
    //public List<Descriptions> Description = new List<Descriptions>();
}

public class Descriptions
{
    public string AuxResult;
    public List<CategoryResults> CategoryResult = new List<CategoryResults>();
}

public class CategoryResults
{
    public string AuxResult;
    public string CategoryName;
    public float Confidence;
}

