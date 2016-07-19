using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace ImageDescriberV3
{
    // LUIS framework class
    public sealed class LuisClient
    {
        private LuisClient() { }

        public static async Task<ImageLuis> ParseUserInput(string input)
        {
            string ret = string.Empty;
            string escaped = Uri.EscapeDataString(input);

            using (var client = new HttpClient())
            {
                string uri = "https://api.projectoxford.ai/luis/v1/application?id=3284f292-e3e2-40ed-bc77-5690c9c754d6&subscription-key=fe2ab8e14ebd4ee998853eee4ace4be2&q=" + escaped;
                HttpResponseMessage msg = await client.GetAsync(uri);

                if (msg.IsSuccessStatusCode)
                {
                    var jsonResponse = await msg.Content.ReadAsStringAsync();
                    var _Data = JsonConvert.DeserializeObject<ImageLuis>(jsonResponse);
                    return _Data;
                }
            }
            return null;
        }
    } 

    public class ImageLuis
    {
        [JsonProperty(PropertyName = "query")]
        public string Query { get; set; }

<<<<<<< HEAD
        [JsonProperty(PropertyName = "intents")]
        internal Collection<LIntent> Intents;

        [JsonProperty(PropertyName = "entities")]
        internal Collection<LEntity> Entities;
    }

    public class LIntent
=======
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
        // Follow Luis Convention
        [JsonProperty(PropertyName = "intents")]
        public IIntent[] Intent { get; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
        // Follow Luis Convention
        [JsonProperty(PropertyName = "entities")]
        public lEntity[] Entities { get; set; }
    }

    public class IIntent
>>>>>>> refs/remotes/MSRCCS/master
    {
        [JsonProperty(PropertyName = "intent")]
        public string Intent { get; set; }

        [JsonProperty(PropertyName = "score")]
        public float Score { get; set; }
    }

    public class LEntity
    {
        [JsonProperty(PropertyName = "entity")]
        public string Entity { get; set; }

        [JsonProperty(PropertyName = "type")]
        public string EntityType { get; set; }

        [JsonProperty(PropertyName = "startIndex")]
        public int StartIndex { get; set; }

        [JsonProperty(PropertyName = "endIndex")]
        public int EndIndex { get; set; }

        [JsonProperty(PropertyName = "score")]
        public float Score { get; set; }
    }

}
