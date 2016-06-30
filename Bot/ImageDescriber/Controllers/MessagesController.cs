using System;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using System.Web.Http;
using Microsoft.Bot.Connector;
using Microsoft.Bot.Connector.Utilities;
using System.IO;

using Microsoft.ProjectOxford.Vision;
using Microsoft.ProjectOxford.Vision.Contract;
using Microsoft.ProjectOxford.Emotion;
using Microsoft.ProjectOxford.Emotion.Contract;
using System.Collections;
using System.Collections.Generic;

using Microsoft.Azure; // Namespace for CloudConfigurationManager
using Microsoft.WindowsAzure.Storage; // Namespace for CloudStorageAccount
using Microsoft.WindowsAzure.Storage.Blob; // Namespace for Blob storage types
using System.ComponentModel;

namespace ImageDescriber
{
    [BotAuthentication]
    public class MessagesController : ApiController
    {
        /// <summary>
        /// POST: api/Messages
        /// Receive a message from a user and reply to it
        /// </summary>

        private static string KeyDes = "cbc1463902284471bf4aaae732da10a0";
        private static string KeyEmo = "ebe3b657187242f684da0318c812c878";
        private static string KeyFace = "4cb2b28396104278867114638f7a75b0";

        // method that handles user messages and sends back replies
        public async Task<Message> Post([FromBody]Message message)
        {
            if (message.Type == "Message")
            {
                SaveMessage(message, message.Created.ToString().Substring(0, 9), false);
                Message ReplyMessage = new Message();
                if (message.Attachments.Count() > 0) // sending image
                {
                    ReplyMessage = message.CreateReplyMessage("What would you like to know?");
                    ReplyMessage.SetBotUserData("ImageStream", message.Attachments[0].ContentUrl);
                    ReplyMessage.SetBotUserData("Attachment", 11); // 11 for attachment, 22 for url
                    SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                    return ReplyMessage;
                }

                if (message.Text.ToLower().Contains("http"))
                {
                    if (message.Text.ToLower().Contains("png") || message.Text.ToLower().Contains("jpg") || message.Text.ToLower().Contains("gif")) // sending url
                    {
                        ReplyMessage = message.CreateReplyMessage("What would you like to know?");
                        ReplyMessage.SetBotUserData("ImageUrl", message.Text);
                        ReplyMessage.SetBotUserData("Attachment", 22); // 11 for attachment, 22 for url
                        SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                        return ReplyMessage;
                    }
                    else
                    {
                        ReplyMessage = message.CreateReplyMessage("Please attach a direct link to the image. The link should end in .jpg, .png, or .gif.");
                        SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                        return ReplyMessage;
                    }
                }
                ImageLUIS luis = await LUISClient.ParseUserInput(message.Text);
                if (luis.intents.Count() > 0)  // identifying the correct intent from LUIS
                {
                    switch (luis.intents[0].intent)
                    {
                        case "None":
                            ReplyMessage = message.CreateReplyMessage("I don't understand what you mean. Please enter in another request.");
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                        case "Describe":
                            ReplyMessage = message.CreateReplyMessage(await Describer(message));
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                        case "Emotion":
                            if (luis.entities.Count() > 0) ReplyMessage = message.CreateReplyMessage(await Emotioner(message, luis.entities[0].entity));
                            else ReplyMessage = message.CreateReplyMessage(await Emotioner(message));
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                        case "Face":
                            ReplyMessage = message.CreateReplyMessage(await Facer(message));
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                        case "ActionsAsk":
                            ReplyMessage = message.CreateReplyMessage("This bot gives information about images. First, either attach an image in the message or as a url. You can then ask the bot about the contents of the image, levels of particular emotions, and people within it (age, gender, celebrities). For example, try asking \"What is the primary emotion?\"");
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                        case "Age":
                            ReplyMessage = message.CreateReplyMessage(await Ager(message));
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                        case "Celebrity":
                            ReplyMessage = message.CreateReplyMessage(await Celebrities(message));
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                        case "Gender":
                            ReplyMessage = message.CreateReplyMessage(await Gender(message));
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                        case "Text":
                            ReplyMessage = message.CreateReplyMessage(await Texter(message));
                            SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                            return ReplyMessage;
                    }
                }
                SaveMessage(ReplyMessage, message.Created.ToString().Substring(0, 9), true);
                return ReplyMessage;  // replying back to user
            }
            else
            {
                return HandleSystemMessage(message);
            }
        }


        // returns image description using CV API call
        public static async Task<string> Describer (Message message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(stream, 1);
                ret = analysisResult.Description.Captions[0].Text + ". Would you like to know anything else?";
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(message.GetBotUserData<string>("ImageUrl"));
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(imageUri.AbsoluteUri, 1);
                ret = analysisResult.Description.Captions[0].Text + ". Would you like to know anything else?";
            }
            return ret;
        }

        // returns primary emotion using Emotion API call
        public static async Task<string> Emotioner (Message message)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(stream);
                ret = CalcEmotion(emotionResult);
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(message.GetBotUserData<string>("ImageUrl"));
                ret = CalcEmotion(emotionResult);
            }
            return ret;
        }

        // helper method that calculates primary emotion
        public static string CalcEmotion (Emotion[] emotionResult)
        {
            string ret = "There is no face detected. Would you like to know anything else?";
            float[] sums = new float[8];
            string[] emotions = { "anger", "contempt", "disgust", "fear", "happiness", "neutral", "sadness", "surpise" };
            if (emotionResult.Length > 0)
            {
                foreach (Emotion emotion in emotionResult)
                {
                    sums[0] += emotion.Scores.Anger;
                    sums[1] += emotion.Scores.Contempt;
                    sums[2] += emotion.Scores.Disgust;
                    sums[3] += emotion.Scores.Fear;
                    sums[4] += emotion.Scores.Happiness;
                    sums[5] += emotion.Scores.Neutral;
                    sums[6] += emotion.Scores.Sadness;
                    sums[7] += emotion.Scores.Surprise;
                }
                ret = "The primary emotion is " + emotions[Array.IndexOf(sums, sums.Max())] + ". Would you like to know anything else?";
            }
            return ret;
        }

        // returns the percentage of a certain emotion using Emotion API call
        public static async Task<string> Emotioner(Message message, string which)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            if (null == ValidEmo(which)) return "Not a valid emotion. Valid emotions are anger, contempt, disgust, fear, happiness, neutral, sadness, and surprise. Please try again.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(stream);
                ret = CalcEmotion(emotionResult, ValidEmo(which));
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(message.GetBotUserData<string>("ImageUrl"));
                ret = CalcEmotion(emotionResult, ValidEmo(which));
            }
            return ret;
        }

        // helper method that checks whether user input is one that is supported
        public static string ValidEmo(string which)
        {
            string ret = null;
            string[,] allEmotions = new string[,] { { "anger", "angry", "angered" }, { "contempt", "contemptuous", "contempted" }, { "disgust", "disgusted", "disgustedness" }, { "fear", "scared", "scaredness" },
                                                    {"happiness", "happy", "joy" }, {"neutral", "neutrality", "neutralness" }, {"sadness", "sad", "sorrow" }, {"surprise", "surprised", "surprisedness" } };
            for (int i = 0; i < 8; i++)
            {
                for (int k = 0; k < 3; k++)
                {
                    if (which.Equals(allEmotions[i, k])) return allEmotions[i, 0];
                }
            }
            return ret;
        }

        // helper method that calculates the percentage of a certain emotion
        public static string CalcEmotion (Emotion[] emotionResult, string which)
        {
            string ret = "There is no face detected. Would you like to know anything else?";
            float val = 0.0F;
            if (emotionResult.Length > 0)
            {
                foreach (Emotion emotion in emotionResult)
                {
                    switch (which.ToLower())
                    {
                        case "anger":
                            val += emotion.Scores.Anger;
                            break;
                        case "contempt":
                            val += emotion.Scores.Contempt;
                            break;
                        case "disgust":
                            val += emotion.Scores.Disgust;
                            break;
                        case "fear":
                            val += emotion.Scores.Fear;
                            break;
                        case "happiness":
                            val += emotion.Scores.Happiness;
                            break;
                        case "neutral":
                            val += emotion.Scores.Neutral;
                            break;
                        case "sadness":
                            val += emotion.Scores.Sadness;
                            break;
                        case "surprise":
                            val += emotion.Scores.Surprise;
                            break;
                    }
                }
                ret = "The level of " + which + " is " + (val/(emotionResult.Length) * 100) + "%. Would you like to know anything else?";
            }
            return ret;
        }

        // returns number of faces using Emotion API call
        public static async Task<string> Facer (Message message)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(stream);
                ret = "There are " + emotionResult.Length + " faces. Would you like to know anything else?";
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(message.GetBotUserData<string>("ImageUrl"));
                ret = "There are " + emotionResult.Length + " faces. Would you like to know anything else?";
            }
            return ret;
        }

        // returns age of people using CV API call
        public static async Task<string> Ager (Message message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                VisualFeature[] visualFeatures = new VisualFeature[] {VisualFeature.Faces};
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(stream, visualFeatures);
                ret = CalcAge(analysisResult);
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(message.GetBotUserData<string>("ImageUrl"));
                VisualFeature[] visualFeatures = new VisualFeature[] {VisualFeature.Faces};
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, visualFeatures);
                ret = CalcAge(analysisResult);
            }
            return ret;
        }

        // helper method that calculates ages
        public static string CalcAge (AnalysisResult analysisResult)
        {
            string ret = "No person detected. Would you like to know anything else?";
            if (analysisResult.Faces.Length == 1)
            {
                ret = "The person's age is " + analysisResult.Faces[0].Age + " years old. Would you like to know anything else?";
            }
            else if (analysisResult.Faces.Length > 1)
            {
                ret = "The ages from left to right are: ";
                List<int> ages = new List<int>();
                List<int> lefts = new List<int>();
                for (int i = 0; i < analysisResult.Faces.Length; i++)
                {
                    ages.Add(analysisResult.Faces[i].Age);
                    lefts.Add(analysisResult.Faces[i].FaceRectangle.Left);
                }
                while (ages.Count > 0)
                {
                    int min = 0;
                    for (int i = 0; i < ages.Count; i++)
                    {
                        if (lefts[i] < lefts[min]) min = i;
                    }
                    ret = ret + ages[min] + ", ";
                    ages.RemoveAt(min);
                    lefts.RemoveAt(min);
                }
                ret = ret + "Would you like to know anything else?";
            }
            return ret;
        }

        // returns celebrities in image using CV API call
        public static async Task<string> Celebrities (Message message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(stream, null, new string[] { "celebrities" });
                ret = CalcCeleb(analysisResult);
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(message.GetBotUserData<string>("ImageUrl"));
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, null, new string[] { "celebrities"} );
                ret = CalcCeleb(analysisResult);
            }
            return ret;
        }

        // helper method that calculates which celebrities are present
        public static string CalcCeleb (AnalysisResult analysisResult)  // need to sort by lefts
        {
            string ret = "No celebrity detected. Would you like to know anything else?";
            if (null != analysisResult.Categories && analysisResult.Categories.Length > 0 && analysisResult.Categories[0].Name.Contains("people") && analysisResult.Categories[0].Detail.ToString().Length > 25) // based on number of characters
            {
                string total = analysisResult.Categories[0].Detail.ToString();
                int start = 0;
                List<string> names = new List<string>();
                while (total.IndexOf("name", start) != -1)
                {
                    start = total.IndexOf("name", start) + 8;
                    int len = total.IndexOf(",", start) - start - 1;
                    names.Add(total.Substring(start, len));
                }
                if (names.Count == 1) ret = "This person is [" + names[0] + "](http://en.wikipedia.org/wiki/" + ReplaceSpace(names[0]) + "). Would you like to know anything else?";
                else
                {
                    ret = "The people are ";
                    for (int i = 0; i < names.Count; i++)
                    {
                        if (i == names.Count - 2)
                            ret = ret + "[" + names[i] + "](http://en.wikipedia.org/wiki/" + ReplaceSpace(names[i]) + ") and ";
                        else if (i == names.Count - 1)
                            ret = ret + "[" + names[i] + "](http://en.wikipedia.org/wiki/" + ReplaceSpace(names[i]) + ").";
                        else
                            ret = ret + "[" + names[i] + "](http://en.wikipedia.org/wiki/" + ReplaceSpace(names[i]) + "), ";
                    }
                    ret = ret + " Would you like to know anything else?";
                }
                    
            }
            return ret;
        }

        public static string ReplaceSpace (string input)
        {
            string ret = "";
            for (int i = 0; i < input.Length; i++)
            {
                if (input[i] == ' ') ret = ret + "_";
                else ret = ret + input[i];
            }
            return ret;
        }
        // returns gender using CV API
        public static async Task<string> Gender (Message message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(stream, visualFeatures);
                ret = CalcGender(analysisResult);
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(message.GetBotUserData<string>("ImageUrl"));
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, visualFeatures);
                ret = CalcGender(analysisResult);
            }
            return ret;
        }

        // helper method that calculates gender
        public static string CalcGender (AnalysisResult analysisResult)
        {
            string ret = "No person detected. Would you like to know anything else?";
            if (analysisResult.Faces.Length == 1)
            {
                ret = "The person's gender is " + analysisResult.Faces[0].Gender + ". Would you like to know anything else?";
            }
            else if (analysisResult.Faces.Length > 1)
            {
                ret = "The genders from left to right are: ";
                List<string> genders = new List<string>();
                List<int> lefts = new List<int>();
                for (int i = 0; i < analysisResult.Faces.Length; i++)
                {
                    genders.Add(analysisResult.Faces[i].Gender);
                    lefts.Add(analysisResult.Faces[i].FaceRectangle.Left);
                }
                while (genders.Count > 0)
                {
                    int min = 0;
                    for (int i = 0; i < genders.Count; i++)
                    {
                        if (lefts[i] < lefts[min]) min = i;
                    }
                    ret = ret + genders[min] + ", ";
                    genders.RemoveAt(min);
                    lefts.RemoveAt(min);
                }
                ret = ret + "Would you like to know anything else?";
            }
            return ret;
        }

        // returns OCR using CV API
        public static async Task<string> Texter (Message message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                OcrResults analysisResult = await VisionServiceClient.RecognizeTextAsync(stream);
                ret = CalcText(analysisResult);
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(message.GetBotUserData<string>("ImageUrl"));
                OcrResults analysisResult = await VisionServiceClient.RecognizeTextAsync(imageUri.AbsoluteUri);
                ret = CalcText(analysisResult);
            }
            return ret;
        }

        // helper method that calculates the text
        public static string CalcText (OcrResults analysisResult)
        {
            string ret = "No text detected. Would you like to know anything else?";
            if (analysisResult != null && analysisResult.Regions != null && analysisResult.Regions.Length > 0)
            {
                ret = "The text says ";
                foreach (var region in analysisResult.Regions)
                {
                    foreach (var line in region.Lines)
                    {
                        foreach (var word in line.Words) ret = ret + word.Text + " ";
                    }
                }
                ret = ret + ". Would you like to know anything else?";
            }
            return ret;
        }


        public static void SaveMessage (Message message, string dateIn, bool reply)
        {
            //Parse the connection string for the storage account.
            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(
                Microsoft.Azure.CloudConfigurationManager.GetSetting("StorageConnectionString"));

            //Create service client for credentialed access to the Blob service.
            CloudBlobClient blobClient = storageAccount.CreateCloudBlobClient();

            //Get a reference to a container.
            CloudBlobContainer container = blobClient.GetContainerReference("image-bot");
            
            //Create the container if it does not already exist.
            container.CreateIfNotExists();

            //Get a reference to an append blob.
            string date = dateIn.Replace('/', '-');
            CloudAppendBlob appendBlob = container.GetAppendBlobReference(date);
            if (!appendBlob.Exists()) appendBlob.CreateOrReplace();
            if (reply) appendBlob.AppendText((ConvertReplyString(message) + Environment.NewLine));
            else appendBlob.AppendText((ConvertMessageString(message) + Environment.NewLine));
        }


        public static string ConvertMessageString(Message message)
        {
            string ret = "{";
            ret = ret + string.Format("\"type\": \"{0}\",{1}", message.Type, Environment.NewLine);
            ret = ret + string.Format("\"id\": \"{0}\",{1}", message.Id, Environment.NewLine);
            ret = ret + string.Format("\"conversationId\": \"{0}\",{1}", message.ConversationId, Environment.NewLine);
            ret = ret + string.Format("\"created\": \"{0}\",{1}", message.Created, Environment.NewLine);
            ret = ret + string.Format("\"language\": \"{0}\",{1}", message.Language, Environment.NewLine);
            ret = ret + string.Format("\"text\": \"{0}\",{1}", message.Text, Environment.NewLine);
            ret = ret + string.Format("\"attachments\": {0}{1}", "[", Environment.NewLine);
            if (message.Attachments != null && message.Attachments.Count > 0)
            {
                for (int i = 0; i < message.Attachments.Count; i++)
                {
                    ret = ret + string.Format("{{\"contentType\": \"{0}\",{1}", message.Attachments[i].ContentType, Environment.NewLine);
                    ret = ret + string.Format("\"contentUrl\": \"{0}\"{1}", message.Attachments[i].ContentUrl, Environment.NewLine);
                }
                ret = ret + string.Format("}}{0}", Environment.NewLine);
            }
            ret = ret + "]," + Environment.NewLine;
            ret = ret + string.Format("\"from\": {0}{1}", "{", Environment.NewLine);
            ret = ret + string.Format("\"name\": \"{0}\",{1}", message.From.Name, Environment.NewLine);
            ret = ret + string.Format("\"channelId\": \"{0}\",{1}", message.From.ChannelId, Environment.NewLine);
            ret = ret + string.Format("\"address\": \"{0}\",{1}", message.From.Address, Environment.NewLine);
            ret = ret + string.Format("\"id\": \"{0}\",{1}", message.From.Id, Environment.NewLine);
            ret = ret + string.Format("\"isBot\": {0} }},{1}", message.From.IsBot, Environment.NewLine);

            ret = ret + string.Format("\"to\": {0}{1}", "{", Environment.NewLine);
            ret = ret + string.Format("\"name\": \"{0}\",{1}", message.To.Name, Environment.NewLine);
            ret = ret + string.Format("\"channelId\": \"{0}\",{1}", message.To.ChannelId, Environment.NewLine);
            ret = ret + string.Format("\"address\": \"{0}\",{1}", message.To.Address, Environment.NewLine);
            ret = ret + string.Format("\"id\": \"{0}\",{1}", message.To.Id, Environment.NewLine);
            ret = ret + string.Format("\"isBot\": {0} }},{1}", message.To.IsBot, Environment.NewLine);

            ret = ret + string.Format("\"participants\": {0}{1}", "[", Environment.NewLine);
            for (int i = 0; i < message.Participants.Count; i++)
            {
                ret = ret + string.Format("{0}{1}\"name\": \"{2}\",{3}", "{", Environment.NewLine, message.Participants[i].Name, Environment.NewLine);
                ret = ret + string.Format("\"channelId\": \"{0}\",{1}", message.Participants[i].ChannelId, Environment.NewLine);
                ret = ret + string.Format("\"address\": \"{0}\",{1}", message.Participants[i].Address, Environment.NewLine);
                ret = ret + string.Format("\"id\": \"{0}\",{1}", message.Participants[i].Id, Environment.NewLine);
                ret = ret + string.Format("\"isBot\": {0} }},{1}", message.Participants[i].IsBot, Environment.NewLine);
            }
            ret = ret + "]," + Environment.NewLine;

            ret = ret + string.Format("\"totalParticipants\": \"{0}\",{1}", message.TotalParticipants, Environment.NewLine);
            ret = ret + string.Format("\"channelMessageId\": \"{0}\",{1}", message.ChannelMessageId, Environment.NewLine);
            ret = ret + string.Format("\"channelConversationId\": \"{0}\",{1}", message.ChannelConversationId, Environment.NewLine);

            ret = ret + string.Format("\"botUserData\": {0}{1}", "{", Environment.NewLine);
            if (message.BotUserData != null)
            {
                if (message.GetBotUserData<string>("ImageStream") != (null)) ret = ret + string.Format("\"ImageStream\": \"{0}\",{1}", message.GetBotUserData<string>("ImageStream"), Environment.NewLine);
                if (message.GetBotUserData<string>("ImageUrl") != (null)) ret = ret + string.Format("\"ImageUrl\": \"{0}\",{1}", message.GetBotUserData<string>("ImageUrl"), Environment.NewLine);
                ret = ret + string.Format("\"Attachment\": \"{0}\",{1}", message.GetBotUserData<int>("Attachment"), Environment.NewLine);
            }
            ret = ret + string.Format("{0}{1}{0}{1}", "}", Environment.NewLine);
            return ret;
        }

        public static string ConvertReplyString (Message message)
        {
            string ret = "{";
            ret = ret + string.Format("\"conversationId\": \"{0}\",{1}", message.ConversationId, Environment.NewLine);
            ret = ret + string.Format("\"language\": \"{0}\",{1}", message.Language, Environment.NewLine);
            ret = ret + string.Format("\"text\": \"{0}\",{1}", message.Text, Environment.NewLine);
            ret = ret + string.Format("\"attachments\": {0}{1}", "[", Environment.NewLine);

            ret = ret + string.Format("\"from\": {0}{1}", "{", Environment.NewLine);
            ret = ret + string.Format("\"name\": \"{0}\",{1}", message.From.Name, Environment.NewLine);
            ret = ret + string.Format("\"channelId\": \"{0}\",{1}", message.From.ChannelId, Environment.NewLine);
            ret = ret + string.Format("\"address\": \"{0}\",{1}", message.From.Address, Environment.NewLine);
            ret = ret + string.Format("\"id\": \"{0}\",{1}", message.From.Id, Environment.NewLine);
            ret = ret + string.Format("\"isBot\": {0} }},{1}", message.From.IsBot, Environment.NewLine);

            ret = ret + string.Format("\"to\": {0}{1}", "{", Environment.NewLine);
            ret = ret + string.Format("\"name\": \"{0}\",{1}", message.To.Name, Environment.NewLine);
            ret = ret + string.Format("\"channelId\": \"{0}\",{1}", message.To.ChannelId, Environment.NewLine);
            ret = ret + string.Format("\"address\": \"{0}\",{1}", message.To.Address, Environment.NewLine);
            ret = ret + string.Format("\"id\": \"{0}\",{1}", message.To.Id, Environment.NewLine);
            ret = ret + string.Format("\"isBot\": {0} }},{1}", message.To.IsBot, Environment.NewLine);
            ret = ret + string.Format("\"replyToMessageId\": \"{0}\",{1}", message.ReplyToMessageId, Environment.NewLine);

            ret = ret + string.Format("\"participants\": {0}{1}", "[", Environment.NewLine);
            for (int i = 0; i < message.Participants.Count; i++)
            {
                ret = ret + string.Format("{0}{1}\"name\": \"{2}\",{3}", "{", Environment.NewLine, message.Participants[i].Name, Environment.NewLine);
                ret = ret + string.Format("\"channelId\": \"{0}\",{1}", message.Participants[i].ChannelId, Environment.NewLine);
                ret = ret + string.Format("\"address\": \"{0}\",{1}", message.Participants[i].Address, Environment.NewLine);
                ret = ret + string.Format("\"id\": \"{0}\",{1}", message.Participants[i].Id, Environment.NewLine);
                ret = ret + string.Format("\"isBot\": {0} }},{1}", message.Participants[i].IsBot, Environment.NewLine);
            }
            ret = ret + "]," + Environment.NewLine;

            ret = ret + string.Format("\"totalParticipants\": \"{0}\",{1}", message.TotalParticipants, Environment.NewLine);
            ret = ret + string.Format("\"channelMessageId\": \"{0}\",{1}", message.ChannelMessageId, Environment.NewLine);
            ret = ret + string.Format("\"channelConversationId\": \"{0}\",{1}", message.ChannelConversationId, Environment.NewLine);

            ret = ret + string.Format("{0}{1}", "}", Environment.NewLine);
            return ret;
        }
        private Message HandleSystemMessage(Message message)
        {
            if (message.Type == "Ping")
            {
                Message reply = message.CreateReplyMessage();
                reply.Type = "Ping";
                return reply;
            }
            else if (message.Type == "DeleteUserData")
            {
                // Implement user deletion here
                // If we handle user deletion, return a real message
            }
            else if (message.Type == "BotAddedToConversation")
            {
            }
            else if (message.Type == "BotRemovedFromConversation")
            {
            }
            else if (message.Type == "UserAddedToConversation")
            {
            }
            else if (message.Type == "UserRemovedFromConversation")
            {
            }
            else if (message.Type == "EndOfConversation")
            {
            }

            return null;
        }
    }
}