using System;
using System.Text;
using System.Net;
using System.IO;
using System.Threading;
using System.Runtime.Serialization.Json;
using System.Collections.Generic;

namespace ImageDescriber
{
    class Translate
    {

        public static string TranslateMethod (string authToken, string textIn, string langTo)
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
                    if (languageNames[i].ToLower().Contains(to.ToLower()) || codes[i].ToLower().Equals(to.ToLower())) return codes[i];
                }
            }
            return null;
        }
    }

    public class AdmAccessToken
    {

        public string access_token { get; set; }

        public string token_type { get; set; }

        public string expires_in { get; set; }

        public string scope { get; set; }
    }
    public class AdmAuthentication
    {
        public static readonly string DatamarketAccessUri = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13";
        private string clientId;
        private string clientSecret;
        private string request;
        private AdmAccessToken token;
        private Timer accessTokenRenewer;
        //Access token expires every 10 minutes. Renew it every 9 minutes only.
        private const int RefreshTokenDuration = 9;

        public AdmAuthentication(string clientId, string clientSecret)
        {
            this.clientId = clientId;
            this.clientSecret = clientSecret;
            //If clientid or client secret has special characters, encode before sending request
            this.request = string.Format("grant_type=client_credentials&client_id={0}&client_secret={1}&scope=http://api.microsofttranslator.com", WebUtility.UrlEncode(clientId), WebUtility.UrlEncode(clientSecret));
            this.token = HttpPost(DatamarketAccessUri, this.request);
            //renew the token every specified minutes
            accessTokenRenewer = new Timer(new TimerCallback(OnTokenExpiredCallback), this, TimeSpan.FromMinutes(RefreshTokenDuration), TimeSpan.FromMilliseconds(-1));
        }
        public AdmAccessToken GetAccessToken()
        {
            return this.token;
        }
        private void RenewAccessToken()
        {
            AdmAccessToken newAccessToken = HttpPost(DatamarketAccessUri, this.request);
            //swap the new token with old one
            //Note: the swap is thread unsafe
            this.token = newAccessToken;
            Console.WriteLine(string.Format("Renewed token for user: {0} is: {1}", this.clientId, this.token.access_token));
        }
        private void OnTokenExpiredCallback(object stateInfo)
        {
            RenewAccessToken();
        }

        private AdmAccessToken HttpPost(string DatamarketAccessUri, string requestDetails)
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
                DataContractJsonSerializer serializer = new DataContractJsonSerializer(typeof(AdmAccessToken));
                //Get deserialized object from JSON stream
                AdmAccessToken token = (AdmAccessToken)serializer.ReadObject(webResponse.GetResponseStream());
                return token;
            }
        }

    }
}
