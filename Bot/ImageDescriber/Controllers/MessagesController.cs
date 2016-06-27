using System;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using System.Web.Http;
using Microsoft.Bot.Connector;
using Microsoft.Bot.Connector.Utilities;
using System.IO;

using Newtonsoft.Json;
using Microsoft.ProjectOxford.Vision;
using Microsoft.ProjectOxford.Vision.Contract;
using Microsoft.ProjectOxford.Emotion;
using Microsoft.ProjectOxford.Emotion.Contract;
using System.Collections;
using System.Collections.Generic;

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
                Message ReplyMessage = new Message();
                if (message.Attachments.Count() > 0) // sending image
                {
                    ReplyMessage = message.CreateReplyMessage("What would you like to know?");
                    ReplyMessage.SetBotUserData("ImageStream", message.Attachments[0].ContentUrl);
                    ReplyMessage.SetBotUserData("Attachment", 11); // 11 for attachment, 22 for url
                    return ReplyMessage;
                }
                if (message.Text.Contains("png") || message.Text.Contains("jpg") || message.Text.Contains("gif")) // sending url
                {
                    ReplyMessage = message.CreateReplyMessage("What would you like to know?");
                    ReplyMessage.SetBotUserData("ImageUrl", message.Text);
                    ReplyMessage.SetBotUserData("Attachment", 22); // 11 for attachment, 22 for url
                    return ReplyMessage;
                }

                ImageLUIS luis = await LUISClient.ParseUserInput(message.Text);
                if (luis.intents.Count() > 0)  // identifying the correct intent from LUIS
                {
                    switch (luis.intents[0].intent)
                    {
                        case "None":
                            ReplyMessage = message.CreateReplyMessage("I don't understand what you mean. Please enter in another request.");
                            return ReplyMessage;
                        case "Describe":
                            ReplyMessage = message.CreateReplyMessage(await Describer(message));
                            return ReplyMessage;
                        case "Emotion":
                            if (luis.entities.Count() > 0) ReplyMessage = message.CreateReplyMessage(await Emotioner(message, luis.entities[0].entity));
                            else ReplyMessage = message.CreateReplyMessage(await Emotioner(message));
                            return ReplyMessage;
                        case "Face":
                            ReplyMessage = message.CreateReplyMessage(await Facer(message));
                            return ReplyMessage;
                        case "ActionsAsk":
                            ReplyMessage = message.CreateReplyMessage("This bot gives information about images. First, either attach an image in the message or as a url. You can then ask the bot about the contents of the image, emotions, and faces within it. For example, try asking \"What is the primary emotion?\"");
                            return ReplyMessage;
                        case "Age":
                            ReplyMessage = message.CreateReplyMessage(await Ager(message));
                            return ReplyMessage;
                        case "Celebrity":
                            ReplyMessage = message.CreateReplyMessage(await Celebrities(message));
                            return ReplyMessage;
                    }
                }
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
            if (!ValidEmo(which)) return "Not a valid emotion. Please try again.";
            if (message.GetBotUserData<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(message.GetBotUserData<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(stream);
                ret = CalcEmotion(emotionResult, which);
            }
            else if (message.GetBotUserData<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(message.GetBotUserData<string>("ImageUrl"));
                ret = CalcEmotion(emotionResult, which);
            }
            return ret;
        }

        // helper method that checks whether user input is one that is supported
        public static bool ValidEmo(string which)
        {
            string[] emotions = { "anger", "contempt", "disgust", "fear", "happiness", "neutral", "sadness", "surpise" };
            return emotions.Contains(which);
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
        public static string CalcCeleb (AnalysisResult analysisResult)
        {
            string ret = "No celebrity detected. Would you like to know anything else?";
            if (analysisResult.Categories.Length > 0 && analysisResult.Categories[0].Name.Contains("people") && analysisResult.Categories[0].Detail.ToString().Length > 25) // based on number of characters
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
                if (names.Count == 1) ret = "This person is " + names[0] + ". Would you like to know anything else?";
                else
                {
                    ret = "The people are ";
                    for (int i = 0; i < names.Count; i++)
                    {
                        if (i == names.Count - 2)
                            ret = ret + names[i] + " and ";
                        else if (i == names.Count - 1)
                            ret = ret + names[i] + ".";
                        else
                            ret = ret + names[i] + ", ";
                    }
                    ret = ret + " Would you like to know anything else?";
                }
                    
            }
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