using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

    [Serializable]
    public class FaceIdentifyClass
    {
        public string personGroupId;
        public List<string> faceIds = new List<string>();
        public int maxNumOfCandidatesReturned;
    }

    [Serializable]
    public class CreatePersonClass
    {
        public string name;
    }
