using Newtonsoft.Json;
using System;
using System.Collections.Generic;
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
    {
        public string intent { get; set; }
        public float score { get; set; }
    }

    public class lEntity
    {
        public string entity { get; set; }
        public string type { get; set; }
        public int startIndex { get; set; }
        public int endIndex { get; set; }
        public float score { get; set; }
    }

}
