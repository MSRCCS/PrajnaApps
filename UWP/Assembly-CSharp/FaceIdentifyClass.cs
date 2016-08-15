using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AssemblyCSharpWSA
{
    [Serializable]
    public class FaceIdentifyClass
    {
        public string personGroupId { get; set; }
        public List<string> faceIds { get; set; } = new List<string>();
        public int maxNumOfCandidatesReturned { get; set; }
    }
}
