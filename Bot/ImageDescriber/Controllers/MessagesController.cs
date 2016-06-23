using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web.Http;
using System.Web.Http.Description;
using Microsoft.Bot.Connector;
using Microsoft.Bot.Connector.Utilities;
using Newtonsoft.Json;
using System.IO;

using Microsoft.ProjectOxford.Vision;
using Microsoft.ProjectOxford.Vision.Contract;
using Microsoft.ProjectOxford.Emotion;
using Microsoft.ProjectOxford.Emotion.Contract;

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
                if (luis.intents.Count() > 0)
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
                    }
                }
                return ReplyMessage;
            }
            else
            {
                return HandleSystemMessage(message);
            }
        }



        public static async Task<string> Describer(Message message) // tested - works
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

        public static async Task<string> Emotioner(Message message)
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

        public static string CalcEmotion(Emotion[] emotionResult)
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


        public static string CalcEmotion(Emotion[] emotionResult, string which)
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
                ret = "The level of " + which + " is " + (val * 100) + ". Would you like to know anything else?";
            }
            return ret;

        }

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

        public static bool ValidEmo(string which)
        {
            string[] emotions = { "anger", "contempt", "disgust", "fear", "happiness", "neutral", "sadness", "surpise" };
            return emotions.Contains(which);
        }


        public static async Task<string> Facer(Message message)
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