using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web.Http;
using Microsoft.Bot.Connector;
using Newtonsoft.Json;
using System.Threading;
using System.Reflection;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Blob;
using System.Text;
using Microsoft.ProjectOxford.Emotion;
using System.IO;

using Microsoft.ProjectOxford.Vision;
using Microsoft.ProjectOxford.Vision.Contract;
using Microsoft.ProjectOxford.Emotion.Contract;
using System.Collections.Generic;
using System.Web;
using Newtonsoft.Json.Linq;

namespace ImageDescriberV3
{
    [BotAuthentication]
    public class MessagesController : ApiController
    {
        /// <summary>
        /// POST: api/Messages
        /// Receive a message from a user and reply to it
        /// </summary>
        /// 
        private static string KeyDes = "cbc1463902284471bf4aaae732da10a0";
        private static string KeyEmo = "ebe3b657187242f684da0318c812c878";
        private static string KeyFace = "4cb2b28396104278867114638f7a75b0";
        private static string IdTrans = "ImageDescriber";
        private static string SecTrans = "3RDYrwAxYga8hPqbjJXlWDDSL1mJpodCE2lvcGae9Qo=";
        private static string KeyBing = "0fc345553fbc45838e0e3b0ffd431cff";

        private static CloudStorageAccount storageAccount = null; // corperate azure account
        private static CloudBlobClient blobClient = null;
        private static CloudBlobContainer container = null;
        private static CloudAppendBlob appendBlob = null;
        private static string AzureContainer = "test-luis-v3";
        private static string Date = null;

        private static SemaphoreSlim semaphore = new SemaphoreSlim(1); // only one thread pushing to azure at a time
        private static StateClient stateClient;
        private static BotState botState;
        private static BotData userData;

        private static bool misinterpret = false; // expecting labeling errors
        private static bool incorrect = false; // expecting annotation errors
        private static bool confirm = false; // expecting button response

        public async Task<HttpResponseMessage> Post([FromBody]Activity message)
        {
            if (message.Type == ActivityTypes.Message)
            {
                ConnectorClient connector = new ConnectorClient(new Uri(message.ServiceUrl));

                stateClient = message.GetStateClient();
                userData = await stateClient.BotState.GetUserDataAsync(message.ChannelId, message.From.Id); // acquire all current userData
                userData.SetProperty<bool>("Message", true); // arbitrary variable - required for userData to function properly

                new Thread(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))).Start(); // log incoming message

                Activity ReplyMessage = new Activity();

                if (await CheckAttachments(message, ReplyMessage, connector)) return Request.CreateResponse(HttpStatusCode.OK); // checks if an image or image url has been sent
                if (await CheckHelpCommand(message, ReplyMessage, connector)) return Request.CreateResponse(HttpStatusCode.OK); // checks if help was requested
                if (await CheckLabelFeedback(message, ReplyMessage, connector)) return Request.CreateResponse(HttpStatusCode.OK); // checks if reporting LUIS label error
                if (await CheckAnnotateFeedback(message, ReplyMessage, connector)) return Request.CreateResponse(HttpStatusCode.OK); // checks if identifying annotation error (or button response)

                ImageLUIS luis = await LUISClient.ParseUserInput(message.Text);
                if (luis.intents.Count() > 0)  // identifying the correct intent from LUIS
                {
                    switch (luis.intents[0].intent)
                    {
                        case "None":
                            ReplyMessage = message.CreateReply("I don't understand what you mean. Please enter in another request.");
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Describe":
                            ReplyMessage = message.CreateReply(await Describer(message));
                            userData.SetProperty<string>("PreviousQ", message.Text);
                            Activity ConfirmMessage = ConfirmButton(message);
                            await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                            await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                            await connector.Conversations.ReplyToActivityAsync(ConfirmMessage);
                            new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                            new Thread(async () => await SaveMessage(ConfirmMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Emotion":
                            if (luis.entities.Count() > 0) ReplyMessage = message.CreateReply(await Emotioner(message, luis.entities[0].entity));
                            else ReplyMessage = message.CreateReply(await Emotioner(message));
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Face":
                            ReplyMessage = message.CreateReply(await Facer(message));
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "ActionsAsk":
                            ReplyMessage = message.CreateReply("This bot provides information about images. After attaching an image or sending an image URL, you can ask the bot about the image's contents, emotions, people, text, and for similar images, using natural language commands. For a full list of functions, enter \"help\".");
                            Activity Reply2 = message.CreateReply("If the bot misinterprets any of your requests, enter \"wrong\". To help us improve the bot, please correct it if it gives you an inaccurate response to your question.");
                            Activity Reply3 = message.CreateReply("To get started, enter an image and try asking \"What is this a picture of\"");
                            new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                            new Thread(async () => await SaveMessage(Reply2, message.Timestamp.ToString().Substring(0, 9))).Start();
                            new Thread(async () => await SaveMessage(Reply3, message.Timestamp.ToString().Substring(0, 9))).Start();
                            await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                            await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                            await connector.Conversations.ReplyToActivityAsync(Reply2);
                            await connector.Conversations.ReplyToActivityAsync(Reply3);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Age":
                            ReplyMessage = message.CreateReply(await Ager(message));
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Celebrity":
                            ReplyMessage = message.CreateReply(await Celebrities(message));
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Gender":
                            ReplyMessage = message.CreateReply(await Gender(message));
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Text":
                            ReplyMessage = message.CreateReply(await Texter(message));
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Translate":
                            if (luis.entities.Count() > 0) ReplyMessage = message.CreateReply(await Translator(message, luis.entities[0].entity));
                            else ReplyMessage = message.CreateReply("You need to specify a language to translate to. Please try again.");
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Annotate":
                            if (userData.GetProperty<string>("PreviousQ") != null) // responding without a previous question
                            {
                                if (luis.entities.Count() > 0) // not identifying the correct annotation
                                {
                                    ReplyMessage = message.CreateReply("Thanks for the feedback - we will use it to better train our models. Would you like to know anything else?");
                                    StringBuilder sb = new StringBuilder();
                                    foreach (lEntity entity in luis.entities) sb.Append(entity.entity + " ");
                                    userData.SetProperty<string>("Annotation", sb.ToString());
                                }
                                else
                                {
                                    ReplyMessage = message.CreateReply("Please specify what the correct annotation is.");
                                    incorrect = true;
                                }
                            }
                            else ReplyMessage = message.CreateReply("Please first ask the bot about the image.");
                            await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                            await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                            new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Similar":
                            ReplyMessage = await Similar(message);
                            await SetDataSendMessage(message, ReplyMessage, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                    }
                }
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start(); // never gets to this point
                return Request.CreateResponse(HttpStatusCode.OK);
            }
            else
            {
                HandleSystemMessage(message);
            }

            return Request.CreateResponse(HttpStatusCode.OK);
        }

        private Activity HandleSystemMessage(Activity message)
        {
            if (message.Type == ActivityTypes.DeleteUserData)
            {
                // Implement user deletion here
                // If we handle user deletion, return a real message
            }
            else if (message.Type == ActivityTypes.ConversationUpdate)
            {
                // Handle conversation state changes, like members being added and removed
                // Use Activity.MembersAdded and Activity.MembersRemoved and Activity.Action for info
                // Not available in all channels
            }
            else if (message.Type == ActivityTypes.ContactRelationUpdate)
            {
                // Handle add/remove from contact lists
                // Activity.From + Activity.Action represent what happened
            }
            else if (message.Type == ActivityTypes.Typing)
            {
                // Handle knowing tha the user is typing
            }
            else if (message.Type == ActivityTypes.Ping)
            {
            }

            return null;
        }

        // initial method to check if sending attachment or URL
        public static async Task<bool> CheckAttachments(Activity message, Activity ReplyMessage, ConnectorClient connector)
        {
            if (message.Attachments != null && message.Attachments.Count() >= 1 && message.Attachments[0].ContentType.ToString().Contains("image")) // sending image + error catching for facebook link thumbnail
            {
                ReplyMessage = message.CreateReply("What would you like to know?");
                userData.SetProperty<string>("ImageStream", message.Attachments[0].ContentUrl); // TODO: skype image attachments do not work because contentUrl is not accessible
                userData.SetProperty<int>("Attachment", 11); // 11 for attachment, 22 for url
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                return true;
            }

            if (message.Text.ToLower().Contains("http"))
            {
                if (message.Text.ToLower().Contains("png") || message.Text.ToLower().Contains("jpg") || message.Text.ToLower().Contains("gif")) // sending url
                {
                    ReplyMessage = message.CreateReply("What would you like to know?");
                    if (!message.ChannelId.Equals("skype")) userData.SetProperty<string>("ImageUrl", message.Text);
                    else userData.SetProperty<string>("ImageUrl", SkypeUrl(message.Text));
                    userData.SetProperty<int>("Attachment", 22);// 11 for attachment, 22 for url
                    await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                    await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                    new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().ToString().Substring(0, 9))).Start();
                    return true;
                }
                else
                {
                    ReplyMessage = message.CreateReply("Please attach a direct link to the image. The link should end in .jpg, .png, or .gif.");
                    await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                    await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                    new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                    return true;
                }
            }
            return false;
        }

        // initial method to see if help is requested
        public static async Task<bool> CheckHelpCommand(Activity message, Activity ReplyMessage, ConnectorClient connector)
        {
            if (message.Text.ToLower().Contains("help") || message.Text.ToLower().Contains("functionality") || message.Text.ToLower().Contains("commands"))
            {
                ReplyMessage = message.CreateReply("Full capabilities: image description, primary emotion, levels of emotions, number of faces, age of people, genders, celebrity recognition, image text detection, image text translation, similar images. To use the bot in a different language, enter \"use\" followed by your language.");
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                return true;
            }
            return false;
        }

        // initial method to see is LUIS label feedback is being given
        public static async Task<bool> CheckLabelFeedback(Activity message, Activity ReplyMessage, ConnectorClient connector)
        {
            if (message.Text.ToLower().Contains("wrong")) // wants to report incorrect labeling
            {
                ReplyMessage = message.CreateReply("Sorry about that. Which of the following describes your intended request: describe, emotion, face, age, gender, celebrity, text, translate. If it is none of these, enter \"none\"");
                misinterpret = true;
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                return true;
            }

            if (misinterpret) // identifying correct labeling
            {
                string[] options = { "None", "Describe", "Emotion", "Face", "Age", "Gender", "Celebrity", "Text", "Translate" }; // possible intents
                foreach (string opt in options)
                {
                    if (message.Text.ToLower().Contains(opt.ToLower()))
                    {
                        ReplyMessage = message.CreateReply("Thanks for the feedback. We will categorize the request as " + opt.ToLower() + " next time. Would you like to know anything else?");
                        misinterpret = false;
                        //ReplyMessage.SetBotConversationData("PreviousQ", message.GetBotConversationData<string>("PreviousQ")); - may not need if data persists
                        await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                        await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                        new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                        return true;
                    }
                }
                ReplyMessage = message.CreateReply("Not a valid option. Which of the following describes your intended request: describe, emotion, face, age, gender, celebrity, text, translate. If it is none of these, enter \"none\"");
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                return true;
            }
            return false;
        }

        // initial method to see if annotation result feedback is being given
        public static async Task<bool> CheckAnnotateFeedback(Activity message, Activity ReplyMessage, ConnectorClient connector)
        {
            if (incorrect) // identifying only correct annotation (after Annotate intent)
            {
                ReplyMessage = message.CreateReply("Thanks for the feedback - we will use it to better train our models. Would you like to know anything else?");
                userData.SetProperty<string>("Annotation", message.Text);
                incorrect = false;
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                return true;
            }

            if (message.Text.Contains("postback")) // message is button response about accuracy
            {
                if (confirm) // expecting button response
                {
                    confirm = false;

                    if (message.Text.Contains("yes")) ReplyMessage = message.CreateReply("Great! Would you like to know anything else?"); // "yes"
                    else if (message.Text.Contains("no")) ReplyMessage = message.CreateReply("Thanks for the feedback! Would you like to know anything else?"); // "no"
                    await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                    await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                    new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                    return true;
                }
                else // not expecting button response
                {
                    ReplyMessage = message.CreateReply("You already responded to this! Would you like to anything else?");
                    await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                    await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
                    new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start();
                    return true;
                }
            }
            return false;
        }

        // general method to set userData and send reply message
        public static async Task SetDataSendMessage(Activity message, Activity ReplyMessage, ConnectorClient connector)
        {
            userData.SetProperty<string>("PreviousQ", message.Text);
            await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
            await connector.Conversations.ReplyToActivityAsync(ReplyMessage);
            new Thread(async () => await SaveMessage(ReplyMessage, message.Timestamp.ToString().Substring(0, 9))).Start(); // log outgoing message
        }

        // converts message text to URL for skype
        public static string SkypeUrl(string text) // gets image url from skype message
        {
            string full = text.Substring(text.IndexOf('>'));
            return full.Substring(1, full.Length - 5);
        }

        // returns description using CV API call
        public static async Task<string> Describer(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(stream, 1);
                ret = analysisResult.Description.Captions[0].Text + ". Would you like to know anything else?";
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(userData.GetProperty<string>("ImageUrl"));
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(imageUri.AbsoluteUri, 1);
                ret = analysisResult.Description.Captions[0].Text + ". Would you like to know anything else?";
            }
            return ret;
        }

        // returns primary emotion using Emotion API call
        public static async Task<string> Emotioner(Activity message)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(stream);
                ret = CalcEmotion(emotionResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(userData.GetProperty<string>("ImageUrl"));
                ret = CalcEmotion(emotionResult);
            }
            return ret;
        }

        // helper method that calculates primary emotion
        public static string CalcEmotion(Emotion[] emotionResult)
        {
            string ret = "There is no emotion detected. Would you like to know anything else?";
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
        public static async Task<string> Emotioner(Activity message, string which)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            if (null == ValidEmo(which)) return "Not a valid emotion. Valid emotions are anger, contempt, disgust, fear, happiness, neutral, sadness, and surprise. Please try again.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(stream);
                ret = CalcEmotion(emotionResult, ValidEmo(which));
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(userData.GetProperty<string>("ImageUrl"));
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
        public static string CalcEmotion(Emotion[] emotionResult, string which)
        {
            string ret = "There is no emotion detected. Would you like to know anything else?";
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
                ret = "The level of " + which + " is " + (val / (emotionResult.Length) * 100) + "%. Would you like to know anything else?";
            }
            return ret;
        }

        // returns number of faces using Emotion API call
        public static async Task<string> Facer(Activity message)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(stream);
                ret = "There are " + emotionResult.Length + " faces. Would you like to know anything else?";
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(userData.GetProperty<string>("ImageUrl"));
                ret = "There are " + emotionResult.Length + " faces. Would you like to know anything else?";
            }
            return ret;
        }

        // returns age of people using CV API call
        public static async Task<string> Ager(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(stream, visualFeatures);
                ret = CalcAge(analysisResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(userData.GetProperty<string>("ImageUrl"));
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, visualFeatures);
                ret = CalcAge(analysisResult);
            }
            return ret;
        }

        // helper method that calculates ages
        public static string CalcAge(AnalysisResult analysisResult)
        {
            string ret = "No person detected. Would you like to know anything else?";
            if (analysisResult.Faces.Length == 1)
            {
                ret = "The person's age is " + analysisResult.Faces[0].Age + " years old. Would you like to know anything else?";
            }
            else if (analysisResult.Faces.Length > 1)
            {
                StringBuilder sb = new StringBuilder();
                sb.Append("The ages from left to right are: ");
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
                    sb.Append(ages[min] + ", ");
                    ages.RemoveAt(min);
                    lefts.RemoveAt(min);
                }
                sb.Append("Would you like to know anything else?");
                ret = sb.ToString();
            }
            return ret;
        }

        // returns celebrities in image using CV API call
        public static async Task<string> Celebrities(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(stream, null, new string[] { "celebrities" });
                ret = CalcCeleb(analysisResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(userData.GetProperty<string>("ImageUrl"));
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, null, new string[] { "celebrities" });
                ret = CalcCeleb(analysisResult);
            }
            return ret;
        }

        // helper method that calculates which celebrities are present
        public static string CalcCeleb(AnalysisResult analysisResult)  // need to sort by lefts
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
                    StringBuilder sb = new StringBuilder();
                    sb.Append("The people are ");
                    for (int i = 0; i < names.Count; i++)
                    {
                        if (i == names.Count - 2)
                            sb.Append("[" + names[i] + "](http://en.wikipedia.org/wiki/" + ReplaceSpace(names[i]) + ") and ");
                        else if (i == names.Count - 1)
                            sb.Append("[" + names[i] + "](http://en.wikipedia.org/wiki/" + ReplaceSpace(names[i]) + ").");
                        else
                            sb.Append("[" + names[i] + "](http://en.wikipedia.org/wiki/" + ReplaceSpace(names[i]) + "), ");
                    }
                    sb.Append(" Would you like to know anything else?");
                    ret = sb.ToString();
                }

            }
            return ret;
        }

        // replaces spaces with underscores for wikipedia
        public static string ReplaceSpace(string input)
        {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < input.Length; i++)
            {
                if (input[i] == ' ') sb.Append("_");
                else sb.Append(input[i]);
            }
            return sb.ToString();
        }

        // returns gender using CV API
        public static async Task<string> Gender(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(stream, visualFeatures);
                ret = CalcGender(analysisResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(userData.GetProperty<string>("ImageUrl"));
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, visualFeatures);
                ret = CalcGender(analysisResult);
            }
            return ret;
        }

        // helper method that calculates gender
        public static string CalcGender(AnalysisResult analysisResult)
        {
            string ret = "No person detected. Would you like to know anything else?";
            if (analysisResult.Faces.Length == 1)
            {
                ret = "The person's gender is " + analysisResult.Faces[0].Gender + ". Would you like to know anything else?";
            }
            else if (analysisResult.Faces.Length > 1)
            {
                StringBuilder sb = new StringBuilder().Append("The genders from left to right are: ");
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
                    sb.Append(genders[min] + ", ");
                    genders.RemoveAt(min);
                    lefts.RemoveAt(min);
                }
                sb.Append("Would you like to know anything else?");
                ret = sb.ToString();
            }
            return ret;
        }

        // returns OCR using CV API
        public static async Task<string> Texter(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                OcrResults analysisResult = await VisionServiceClient.RecognizeTextAsync(stream);
                ret = CalcText(analysisResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(userData.GetProperty<string>("ImageUrl"));
                OcrResults analysisResult = await VisionServiceClient.RecognizeTextAsync(imageUri.AbsoluteUri);
                ret = CalcText(analysisResult);
            }
            return ret;
        }

        // helper method that calculates the text
        public static string CalcText(OcrResults analysisResult)
        {
            string ret = "No text detected. Would you like to know anything else?";
            if (analysisResult != null && analysisResult.Regions != null && analysisResult.Regions.Length > 0)
            {
                StringBuilder sb = new StringBuilder().Append("The text says ");
                foreach (var region in analysisResult.Regions)
                {
                    foreach (var line in region.Lines)
                    {
                        foreach (var word in line.Words) sb.Append(word.Text + " ");
                    }
                }
                if (ret[ret.Length - 1] != '.') sb.Append('.');
                sb.Append(" Would you like to know anything else?");
                ret = sb.ToString();
            }
            return ret;
        }

        // logs message to azure blob
        public static async Task SaveMessage(Activity message, string dateIn)
        {
            await semaphore.WaitAsync();
            if (storageAccount == null)
            {
                storageAccount = CloudStorageAccount.Parse(Microsoft.Azure.CloudConfigurationManager.GetSetting("StorageConnectionString"));
                blobClient = storageAccount.CreateCloudBlobClient();
                container = blobClient.GetContainerReference(AzureContainer);
                container.CreateIfNotExists();
            }

            if (Date == null || appendBlob == null || !Date.Equals(dateIn.Replace('/', '-')))
            {
                Date = dateIn.Replace('/', '-');
                appendBlob = container.GetAppendBlobReference(Date);
                if (!appendBlob.Exists()) await appendBlob.CreateOrReplaceAsync();
            }

            await appendBlob.AppendTextAsync((ConvertToJson(message) + Environment.NewLine));
            semaphore.Release();
        }

        // converts message in to json using newtonsoft and messageclass class
        public static string ConvertToJson(Activity message)
        {
            MessageClass output = new MessageClass();

            var type = typeof(Activity);
            PropertyInfo[] propertiesM = type.GetProperties();

            var type2 = typeof(MessageClass);
            PropertyInfo[] propertiesMC = type2.GetProperties();

            for (int i = 0; i < propertiesM.Length; i++)
            {
                for (int k = 0; k < propertiesMC.Length; k++)
                {
                    if (propertiesM[i].Name.ToLower().Equals(propertiesMC[k].Name.ToLower()))
                    {
                        var value = propertiesM[i].GetValue(message);
                        propertiesMC[k].SetValue(output, value);
                    }
                }
            }
            if (userData.GetProperty<string>("Annotation") != null) output.userData.Annotation = userData.GetProperty<string>("Annotation");
            if (userData.GetProperty<int>("Attachment") > 10) output.userData.Attachment = userData.GetProperty<int>("Attachment");
            if (userData.GetProperty<string>("ImageStream") != null) output.userData.ImageStream = userData.GetProperty<string>("ImageStream");
            if (userData.GetProperty<string>("ImageUrl") != null) output.userData.ImageUrl = userData.GetProperty<string>("ImageUrl");
            if (userData.GetProperty<string>("PreviousQ") != null) output.userData.PreviousQ = userData.GetProperty<string>("PreviousQ");

            return JsonConvert.SerializeObject(output, Formatting.Indented);
        }

        // returns translation of text within a message to a specified language using Microsoft Translator API call
        public static async Task<string> Translator(Activity message, string to)
        {
            string text = await Texter(message);
            string ret = text;
            if (ret.Contains("No text detected") || ret.Contains("Please first attach")) return ret;
            else
            {
                text = text.Replace("The text says", " ").Replace(". Would you like to know anything else?", " ");
                text = text.Trim();
                AdmAccessToken admToken;
                string headerValue;
                AdmAuthentication admAuth = new AdmAuthentication(IdTrans, SecTrans);
                admToken = admAuth.GetAccessToken();
                headerValue = "Bearer " + admToken.access_token;
                string langTo = Translate.CheckLanguage(headerValue, to);

                if (langTo == null) ret = "Not a valid language name. Try again.";
                else
                {
                    StringBuilder sb = new StringBuilder().Append("The translation is " + Translate.TranslateMethod(headerValue, text, langTo));
                    if (ret[ret.Length - 1] != '.') sb.Append('.');
                    sb.Append(" Would you like to know anything else?");
                    ret = sb.ToString();
                }
            }
            return ret;
        }

        // returns an activity with a button to confirm accuracy of caption
        public static Activity ConfirmButton(Activity message)
        {
            confirm = true;
            if (message.ChannelId.Equals("facebook")) return FacebookButton(message);
            return CreateButton(message);
        }

        // helper method to create accuracy confirming button
        public static Activity CreateButton(Activity message) // works for skype (POSTBACK buttons not yet supported), emulator 
        {
            Activity replyToConversation = message.CreateReply("Is this correct?");
            replyToConversation.Recipient = message.From;
            replyToConversation.Type = "message";
            replyToConversation.Attachments = new List<Attachment>();
            List<CardAction> cardButtons = new List<CardAction>();

            CardAction plButton = new CardAction()
            {
                Value = "postbackyes", // correct caption
                Type = "postBack",
                Title = "Yes"
            };

            CardAction p2Button = new CardAction()
            {
                Value = "postbackno", // incorrect caption
                Type = "postBack",
                Title = "No"
            };

            cardButtons.Add(plButton);
            cardButtons.Add(p2Button);

            HeroCard plCard = new HeroCard()
            {
                Buttons = cardButtons
            };

            Attachment plAttachment = plCard.ToAttachment();
            replyToConversation.Attachments.Add(plAttachment);
            return replyToConversation;
        }

        // helper method to create accuracy confirming button
        public static Activity FacebookButton(Activity input) // works for facebook
        {
            Activity reply = input.CreateReply("");
            FacebookMessage message = new FacebookMessage();
            message.notification_type = "REGULAR";
            message.attachment.type = "template";
            message.attachment.payload.template_type = "button";
            message.attachment.payload.text = "Is this correct?";
            message.attachment.payload.buttons = new List<Button>();
            message.attachment.payload.buttons.Add(new Button("postback", "postbackyes", "Yes")); // correct caption
            message.attachment.payload.buttons.Add(new Button("postback", "postbackno", "No")); // incorrect caption
            reply.ChannelData = message;
            return reply;
        }

        // method that returns activity that displays similar images in a carousel
        public static async Task<Activity> Similar(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                WebRequest req = WebRequest.Create(userData.GetProperty<string>("ImageStream"));
                WebResponse response = req.GetResponse();
                Stream stream = response.GetResponseStream();
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(stream, 1);
                if (message.ChannelId.Equals("facebook")) return await FacebookCarousel(message, analysisResult.Description.Captions[0].Text);
                else return await CreateCarousel(message, analysisResult.Description.Captions[0].Text);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = new Uri(userData.GetProperty<string>("ImageUrl"));
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(imageUri.AbsoluteUri, 1);
                if (message.ChannelId.Equals("facebook")) return await FacebookCarousel(message, analysisResult.Description.Captions[0].Text);
                else return await CreateCarousel(message, analysisResult.Description.Captions[0].Text);
            }
            return message.CreateReply("Please first attach an image and enter an image URL.");
        }

        // helper method that returns Json of similar photos using Bing Image Search API call
        public static async Task<JObject> SimilarPictures(string query)
        {
            var client = new HttpClient();
            var queryString = HttpUtility.ParseQueryString(string.Empty);

            // Request headers
            client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", KeyBing);

            // Request parameters
            queryString["q"] = query;
            queryString["count"] = "5";
            queryString["offset"] = "0";
            queryString["mkt"] = "en-us";
            queryString["safeSearch"] = "Moderate";
            var uri = "https://api.cognitive.microsoft.com/bing/v5.0/images/search?" + queryString;

            var response = await client.GetAsync(uri);
            string rep = await response.Content.ReadAsStringAsync();
            return JObject.Parse(rep);
        }

        // helper method that creates similar image carousel
        public static async Task<Activity> CreateCarousel(Activity message, string query) // for skype, emulator
        {
            JObject json = await SimilarPictures(query);

            Activity replyToConversation = message.CreateReply("Here are some more pictures:");
            replyToConversation.Recipient = message.From;
            replyToConversation.Type = "message";
            replyToConversation.Attachments = new List<Attachment>();
            replyToConversation.AttachmentLayout = "carousel";

            for (int i = 0; i < 5; i++)
            {
                List<CardImage> cardImages = new List<CardImage>();
                cardImages.Add(new CardImage((json["value"][i]["contentUrl"]).ToString()));
                HeroCard card = new HeroCard()
                {
                    Images = cardImages
                };
                replyToConversation.Attachments.Add(card.ToAttachment());
            }
            return replyToConversation;
        }

        // helper method that creates similar image carousel
        public static async Task<Activity> FacebookCarousel(Activity input, string query) // for facebook
        {
            Activity reply = input.CreateReply("");
            FacebookMessage message = new FacebookMessage();
            message.notification_type = "REGULAR";
            message.attachment.type = "template";
            message.attachment.payload.template_type = "generic";
            message.attachment.payload.elements = new List<Element>();
            JObject json = await SimilarPictures(query);
            for (int i = 0; i < 5; i++) message.attachment.payload.elements.Add(new Element((json["value"][i]["name"]).ToString(), (json["value"][i]["contentUrl"]).ToString()/*, (json["value"][i]["hostPageUrl"]).ToString()*/));
            reply.ChannelData = message;
            return reply;
        }
    }
}