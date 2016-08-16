using UnityEngine;
using System.Collections;
using System;
using System.Collections.Generic;

[Serializable]
public class PrajnaClassifiers
{
    public List<Classifier> Classifiers = new List<Classifier>();
}

public class Classifier
{
    public string EngineName;
    public string EngineGuid;
    public string Name;
    public string Parameter;
    public string ServiceID;
    public int Version;
}
