using System;
using System.Text;
using System.Net;
using System.IO;
using System.Threading;
using System.Runtime.Serialization.Json;
using System.Collections.Generic;
using System.Globalization;

namespace ImageDescriberV3
{
    // class for Microsoft Translator API methods
    static class Translate
    {

        public static string TranslateMethod(string authToken, string textIn, string langTo)
        {
            string ret = "Not an applicable lanugage. Please try again.";
            string uri = "http://api.microsofttranslator.com/v2/Http.svc/Translate?text=" + WebUtility.UrlEncode(textIn) + "&to=" + langTo;
            HttpWebRequest httpWebRequest = (HttpWebRequest)WebRequest.Create(uri);
            httpWebRequest.Headers.Add("Authorization", authToken);
            WebResponse response = null;
            response = httpWebRequest.GetResponse();
            using (Stream stream = response.GetResponseStream())
            {
                System.Runtime.Serialization.DataContractSerializer dcs = new System.Runtime.Serialization.DataContractSerializer(Type.GetType("System.String"));
                ret = (string)dcs.ReadObject(stream);
                if (response != null)
                {
                    response.Close();
                    response = null;
                }
            }
            return ret;
        }

        private static List<string> GetLanguagesForTranslate(string authToken)
        {

            string uri = "http://api.microsofttranslator.com/v2/Http.svc/GetLanguagesForTranslate";
            HttpWebRequest httpWebRequest = (HttpWebRequest)WebRequest.Create(uri);
            httpWebRequest.Headers.Add("Authorization", authToken);
            WebResponse response = null;
            response = httpWebRequest.GetResponse();
            using (Stream stream = response.GetResponseStream())
            {
                System.Runtime.Serialization.DataContractSerializer dcs = new System.Runtime.Serialization.DataContractSerializer(typeof(List<string>));
                return (List<string>)dcs.ReadObject(stream);
            }
        }

        public static string CheckLanguage(string authToken, string to)
        {
            string uri = "http://api.microsofttranslator.com/v2/Http.svc/GetLanguageNames?locale=en";
            // create the request
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(uri);
            request.Headers.Add("Authorization", authToken);
            request.ContentType = "text/xml";
            request.Method = "POST";
            System.Runtime.Serialization.DataContractSerializer dcs = new System.Runtime.Serialization.DataContractSerializer(Type.GetType("System.Collections.Generic.List`1[System.String]"));
            List<string> codes = GetLanguagesForTranslate(authToken);
            using (System.IO.Stream stream = request.GetRequestStream())
            {
                dcs.WriteObject(stream, codes);
            }
            WebResponse response = null;

            response = request.GetResponse();

            using (Stream stream = response.GetResponseStream())
            {
                List<string> languageNames = (List<string>)dcs.ReadObject(stream);
                for (int i = 0; i < languageNames.Count; i++)
                {
                    if (languageNames[i].ToLower(CultureInfo.CurrentCulture).Contains(to.ToLower(CultureInfo.CurrentCulture)) || codes[i].ToLower(CultureInfo.CurrentCulture).Equals(to.ToLower(CultureInfo.CurrentCulture))) return codes[i];
                }
            }
            return null;
        }
    }

    public class AccessToken
    {
        // Translator API sample code follows this format. 
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Naming", "CA1707:IdentifiersShouldNotContainUnderscores")]
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Naming", "CA1709:IdentifiersShouldBeCasedCorrectly")]
        public string access_token { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Naming", "CA1707:IdentifiersShouldNotContainUnderscores")]
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Naming", "CA1709:IdentifiersShouldBeCasedCorrectly")]
        public string token_type { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Naming", "CA1707:IdentifiersShouldNotContainUnderscores")]
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Naming", "CA1709:IdentifiersShouldBeCasedCorrectly")]
        public string expires_in { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Naming", "CA1709:IdentifiersShouldBeCasedCorrectly")]
        public string scope { get; set; }
    }

    public class TranslateAuthentication
    {
        public static readonly string AccessUri = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13";
        private string request;
        public AccessToken Token { get; }

        public TranslateAuthentication(string clientId, string clientSecret)
        {
            this.request = string.Format(CultureInfo.InvariantCulture, "grant_type=client_credentials&client_id={0}&client_secret={1}&scope=http://api.microsofttranslator.com", WebUtility.UrlEncode(clientId), WebUtility.UrlEncode(clientSecret));
            this.Token = HttpPost(AccessUri, this.request);
        }

        private static AccessToken HttpPost(string DatamarketAccessUri, string requestDetails)
        {
            //Prepare OAuth request 
            WebRequest webRequest = WebRequest.Create(DatamarketAccessUri);
            webRequest.ContentType = "application/x-www-form-urlencoded";
            webRequest.Method = "POST";
            byte[] bytes = Encoding.ASCII.GetBytes(requestDetails);
            webRequest.ContentLength = bytes.Length;
            using (Stream outputStream = webRequest.GetRequestStream())
            {
                outputStream.Write(bytes, 0, bytes.Length);
            }
            using (WebResponse webResponse = webRequest.GetResponse())
            {
                DataContractJsonSerializer serializer = new DataContractJsonSerializer(typeof(AccessToken));
                //Get deserialized object from JSON stream
                return (AccessToken)serializer.ReadObject(webResponse.GetResponseStream());
            }
        }

    }
}
