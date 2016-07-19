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
using System.Net.Http.Headers;
using System.Collections.ObjectModel;
using System.Globalization;

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
        private static string IdTrans = "ImageDescriber";
        private static string SecTrans = "3RDYrwAxYga8hPqbjJXlWDDSL1mJpodCE2lvcGae9Qo=";
        private static string KeyBing = "0fc345553fbc45838e0e3b0ffd431cff";

        private static CloudStorageAccount storageAccount = null; // corperate azure account
        private static CloudBlobClient blobClient = null;
        private static CloudBlobContainer container = null;
        private static CloudAppendBlob appendBlob = null;
        private static string AzureContainer = "test-luis-v3";
        private static string Date = null;

        private static SemaphoreSlim semaphore = new SemaphoreSlim(1); // only one task pushing to azure at a time
        private static StateClient stateClient;
        private static BotData userData = null;

        private static bool misinterpret = false; // expecting labeling errors
        private static bool incorrect = false; // expecting annotation errors
        private static bool confirm = false; // expecting button response

        private static string messageEnding = " Would you like to know anything else?";

        public async Task<HttpResponseMessage> Post([FromBody]Activity message)
        {
            if (message.Type == ActivityTypes.Message)
            {
                ConnectorClient connector = new ConnectorClient(new Uri(message.ServiceUrl));

                stateClient = message.GetStateClient();
                userData = await stateClient.BotState.GetUserDataAsync(message.ChannelId, message.From.Id); // acquire all current userData
                userData.SetProperty<bool>("Message", true); // arbitrary variable - required for userData to function properly

                Activity reply = new Activity();

                if (await CheckAttachments(message, reply, connector)) return Request.CreateResponse(HttpStatusCode.OK); // checks if an image or image url has been sent
                if (await CheckHelpCommand(message, reply, connector)) return Request.CreateResponse(HttpStatusCode.OK); // checks if help was requested
                if (await CheckLabelFeedback(message, reply, connector)) return Request.CreateResponse(HttpStatusCode.OK); // checks if reporting LUIS label error
                if (await CheckAnnotateFeedback(message, reply, connector)) return Request.CreateResponse(HttpStatusCode.OK); // checks if identifying annotation error (or button response)

                ImageLuis luis = await LuisClient.ParseUserInput(message.Text);
<<<<<<< HEAD

                for (int i = 0; i < luis.Intents.Count(); i++)
                {
                    if (i == 0 || (i > 0 && luis.Intents[i].Score > 0.75)) await ChooseIntent(message, connector, luis, luis.Intents[i].Intent); // rarely detects multiple intents due to nature of LUIS
                    else break;
=======
                foreach ( IIntent intent in luis.Intent ) // identifying the correct intent from LUIS
                {
                    switch (intent.intent)
                    {
                        case "None":
                            reply = message.CreateReply("I don't understand what you mean. Please enter in another request. For a full list of commands, enter \"help\".");
                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Describe":
                            reply = message.CreateReply(await Describe(message));
                            userData.SetProperty<string>("PreviousQ", message.Text);
                            Activity confirm = ConfirmButton(message);
                            await SetDataSendMessage(message, new Collection<Activity>() { reply, confirm }, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Emotion":
                            // Please change the code to deal with multiple emotions. 
                            if (luis.Entities.Count() > 0) reply = message.CreateReply(await Emotion(message, luis.Entities[0].entity));
                            else reply = message.CreateReply(await Emotion(message));
                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Face":
                            reply = message.CreateReply(await Face(message));
                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "ActionsAsk":
                            reply = message.CreateReply("This bot provides information about images. After attaching an image or sending an image URL, you can ask the bot about the image's contents, emotions, people, text, and for similar images, using natural language commands. For a full list of functions, enter \"help\".");
                            Activity reply2 = message.CreateReply("If the bot misinterprets any of your requests, enter \"wrong\". To help us improve the bot, please correct it if it gives you an inaccurate response to your question.");
                            Activity reply3 = message.CreateReply("To get started, enter an image and try asking \"What is this a picture of\".");
                            await SetDataSendMessage(message, new Collection<Activity>() { reply, reply2, reply3 }, connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Age":
                            reply = message.CreateReply(await Age(message));
                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Celebrity":
                            reply = message.CreateReply(await Celebrities(message));
                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Gender":
                            reply = message.CreateReply(await Gender(message));
                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Text":
                            reply = message.CreateReply(await Text(message));
                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Translate":
                            // We will translate into first language 
                            if (luis.Entities.Count() == 1)
                                reply = message.CreateReply(await Translator(message, luis.Entities[0].entity));
                            else if ( luis.Entities.Count() == 0 ) 
                                reply = message.CreateReply("You need to specify a language to translate to. Please try again.");
                            else 
                                reply = message.CreateReply("You can't specify more than one language to translate to. Please try again.");

                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);

                        case "Similar":
                            reply = await Similar(message);
                            await SetDataSendMessage(message, new Collection<Activity>() { reply } , connector);
                            return Request.CreateResponse(HttpStatusCode.OK);
                        case "Annotate":
                            if (userData.GetProperty<string>("PreviousQ") != null) // responding without a previous question
                            {
                                if (luis.Entities.Count() == 1) // not identifying the correct annotation
                                {
                                    reply = message.CreateReply("Thanks for the feedback - we will use it to better train our models. Would you like to know anything else?");
                                    StringBuilder sb = new StringBuilder();
                                    foreach (lEntity entity in luis.Entities) sb.Append(entity.entity + " ");
                                    userData.SetProperty<string>("Annotation", sb.ToString());
                                }
                                else if (luis.Entities.Count() == 0)
                                {
                                    reply = message.CreateReply("Please identify what the correct annotation is.");
                                    incorrect = true;
                                }
                                else
                                {
                                    reply = message.CreateReply("You specify more than one annotations, that confuses me. ");
                                    incorrect = true;
                                }
                            }
                            else reply = message.CreateReply("Please first ask the bot about the image.");
                            await connector.Conversations.ReplyToActivityAsync(reply);
                            await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                            await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                            await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                            return Request.CreateResponse(HttpStatusCode.OK);
                    }
>>>>>>> refs/remotes/MSRCCS/master
                }
                return Request.CreateResponse(HttpStatusCode.OK);
            }
            else
            {
                HandleSystemMessage(message);
            }

            return Request.CreateResponse(HttpStatusCode.OK);
        }

        private static Activity HandleSystemMessage(Activity message)
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

        //////////// INITIAL MESSAGE CHECKS ////////////
        // initial method to check if sending attachment or URL
        public static async Task<bool> CheckAttachments(Activity message, Activity reply, ConnectorClient connector)
        {
            if (message.Attachments != null && message.Attachments.Count() >= 1 && message.Attachments[0].ContentType.ToString().Contains("image")) // sending image + error catching for facebook link thumbnail
            {
                reply = message.CreateReply("What would you like to know?");
                userData.SetProperty<Uri>("ImageUrl", new Uri(message.Attachments[0].ContentUrl));
                userData.SetProperty<int>("Attachment", 11); // 11 for attachment, 22 for url
                await connector.Conversations.ReplyToActivityAsync(reply);
                await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                return true;
            }

            if (message.Text.ToLower().Contains("http"))
            {
                if (message.Text.ToLower().Contains("png") || message.Text.ToLower().Contains("jpg") || message.Text.ToLower().Contains("gif")) // sending url
                {
                    reply = message.CreateReply("What would you like to know?");
                    if (!message.ChannelId.Equals("skype")) userData.SetProperty<Uri>("ImageUrl", new Uri(message.Text));
                    else userData.SetProperty<Uri>("ImageUrl", SkypeUrl(message.Text));
                    userData.SetProperty<int>("Attachment", 22);// 11 for attachment, 22 for url
                    await connector.Conversations.ReplyToActivityAsync(reply);
                    await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                    new Thread(async () => await SaveMessage(reply, message.Timestamp.ToString().ToString().Substring(0, 9))).Start();
                    await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                    return true;
                }
                else
                {
                    reply = message.CreateReply("Please attach a direct link to the image. The link should end in .jpg, .png, or .gif.");
                    await connector.Conversations.ReplyToActivityAsync(reply);
                    await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                    await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                    await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                    return true;
                }
            }
            return false;
        }

        // initial method to see if help is requested
        public static async Task<bool> CheckHelpCommand(Activity message, Activity reply, ConnectorClient connector)
        {
            if (message.Text.ToLower().Contains("help") || message.Text.ToLower().Contains("functionality") || message.Text.ToLower().Contains("commands"))
            {
                reply = message.CreateReply("Full capabilities: image description, primary emotion, levels of emotions, number of faces, age of people, genders, celebrity recognition, image text detection, image text translation, similar images. To use the bot in a different language, enter \"use\" followed by your language.");
                await connector.Conversations.ReplyToActivityAsync(reply);
                await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                return true;
            }
            return false;
        }

        // initial method to see is LUIS label feedback is being given
        public static async Task<bool> CheckLabelFeedback(Activity message, Activity reply, ConnectorClient connector)
        {
            if (message.Text.ToLower().Contains("wrong")) // wants to report incorrect labeling
            {
                reply = message.CreateReply("Sorry about that. Which of the following describes your intended request: describe, emotion, face, age, gender, celebrity, text, translate, similar. If it is none of these, enter \"none\"");
                misinterpret = true;
                await connector.Conversations.ReplyToActivityAsync(reply);
                await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                return true;
            }

            if (misinterpret) // identifying correct labeling
            {
                string[] options = { "None", "Describe", "Emotion", "Face", "Age", "Gender", "Celebrity", "Text", "Translate", "Similar" }; // possible intents
                foreach (string opt in options)
                {
                    if (message.Text.ToLower().Contains(opt.ToLower()))
                    {
                        reply = message.CreateReply("Thanks for the feedback. We will categorize the request as " + opt.ToLower() + " next time. Here's your intended request: ");
                        misinterpret = false;
                        await connector.Conversations.ReplyToActivityAsync(reply);
                        await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                        await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));

                        await ChooseIntent(message, connector, await LuisClient.ParseUserInput(userData.GetProperty<string>("PreviousQ")), opt);
                        return true;
                    }
                }
                reply = message.CreateReply("Not a valid option. Which of the following describes your intended request: describe, emotion, face, age, gender, celebrity, text, translate, similar. If it is none of these, enter \"none\"");
                await connector.Conversations.ReplyToActivityAsync(reply);
                await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                return true;
            }
            return false;
        }

        // initial method to see if annotation result feedback is being given
        public static async Task<bool> CheckAnnotateFeedback(Activity message, Activity reply, ConnectorClient connector)
        {
            if (incorrect) // identifying only correct annotation (after Annotate intent)
            {
                reply = message.CreateReply("Thanks for the feedback - we will use it to better train our models." + messageEnding);
                userData.SetProperty<string>("Annotation", message.Text);
                incorrect = false;
                await connector.Conversations.ReplyToActivityAsync(reply);
                await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                return true;
            }

            if (message.Text.Contains("postback")) // message is button response about accuracy
            {
                if (confirm) // expecting button response
                {
                    confirm = false;

                    if (message.Text.Contains("yes")) reply = message.CreateReply("Great!" + messageEnding); // "yes"
                    else if (message.Text.Contains("no")) reply = message.CreateReply("Thanks for the feedback!" + messageEnding); // "no"
                    await connector.Conversations.ReplyToActivityAsync(reply);
                    await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                    await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                    await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                    return true;
                }
                else // not expecting button response
                {
                    reply = message.CreateReply("You already responded to this!" + messageEnding);
                    await connector.Conversations.ReplyToActivityAsync(reply);
                    await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
                    await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
                    await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
                    return true;
                }
            }
            return false;
        }

        //////////// INTENT CHECKING ////////////
        public static async Task ChooseIntent(Activity message, ConnectorClient connector, ImageLuis luis, string intent)
        {
            switch (intent)
            {
                case "None":
                    await NoneIntent(message, connector, luis);
                    break;
                case "Describe":
                    await DescribeIntent(message, connector, luis);
                    break;
                case "Emotion":
                    await EmotionIntent(message, connector, luis);
                    break;
                case "Face":
                    await FaceIntent(message, connector, luis);
                    break;
                case "ActionsAsk":
                    await ActionsAskIntent(message, connector, luis);
                    break;
                case "Age":
                    await AgeIntent(message, connector, luis);
                    break;
                case "Celebrity":
                    await CelebrityIntent(message, connector, luis);
                    break;
                case "Gender":
                    await GenderIntent(message, connector, luis);
                    break;
                case "Text":
                    await TextIntent(message, connector, luis);
                    break;
                case "Translate":
                    await TranslateIntent(message, connector, luis);
                    break;
                case "Similar":
                    await SimilarIntent(message, connector, luis);
                    break;
                case "Annotate":
                    await AnnotateIntent(message, connector, luis);
                    break;
            }
        }

        public static async Task NoneIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = message.CreateReply("I don't understand what you mean. Please enter in another request. For a full list of commands, enter \"help\".");
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }

        public static async Task DescribeIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = message.CreateReply(await Describe(message));
            Activity confirm = ConfirmButton(message);
            await SetDataSendMessage(message, new Collection<Activity>() { reply, confirm }, connector);
        }

        public static async Task EmotionIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = new Activity();
            if (luis.Entities.Count() > 0)
            {
                Collection<string> emotions = new Collection<string>();
                foreach (LEntity entity in luis.Entities) emotions.Add(entity.Entity);
                reply = message.CreateReply(await Emotion(message, emotions));
            }
            else reply = message.CreateReply(await Emotion(message));
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }

        public static async Task FaceIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = message.CreateReply(await Face(message));
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }

        public static async Task ActionsAskIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = message.CreateReply("This bot provides information about images. After attaching an image or sending an image URL, you can ask the bot about the image's contents, emotions, people, text, and for similar images, using natural language commands. For a full list of functions, enter \"help\".");
            Activity reply2 = message.CreateReply("If the bot misinterprets any of your requests, enter \"wrong\". To help us improve the bot, please correct it if it gives you an inaccurate response to your question.");
            Activity reply3 = message.CreateReply("To get started, enter an image and try asking \"What is this a picture of\".");
            await SetDataSendMessage(message, new Collection<Activity>() { reply, reply2, reply3 }, connector);
        }

        public static async Task AgeIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = message.CreateReply(await Age(message));
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }
        public static async Task CelebrityIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = message.CreateReply(await Celebrities(message));
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }

        public static async Task GenderIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = message.CreateReply(await Gender(message));
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }

        public static async Task TextIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = message.CreateReply(await Text(message));
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }
        public static async Task TranslateIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            // We will translate into first language   
            Activity reply = new Activity();
            if (luis.Entities.Count() == 1) reply = message.CreateReply(await Translator(message, luis.Entities[0].Entity));
            else if (luis.Entities.Count() == 0) reply = message.CreateReply("You need to specify a language to translate to. Please try again.");
            else reply = message.CreateReply("You can't specify more than one language to translate to. Please try again.");
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }

        public static async Task SimilarIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = await Similar(message);
            await SetDataSendMessage(message, new Collection<Activity>() { reply }, connector);
        }

        public static async Task AnnotateIntent(Activity message, ConnectorClient connector, ImageLuis luis)
        {
            Activity reply = new Activity();
            if (userData.GetProperty<string>("PreviousQ") != null) // responding without a previous question
            {
                if (luis.Entities.Count() == 1) // identifying the correct annotation
                {
                    reply = message.CreateReply("Thanks for the feedback - we will use it to better train our models." + messageEnding);
                    StringBuilder sb = new StringBuilder();
                    foreach (LEntity entity in luis.Entities) sb.Append(entity.Entity + " ");
                    userData.SetProperty<string>("Annotation", sb.ToString());
                }
                else if (luis.Entities.Count() == 0) // not identifying correct annotation
                {
                    reply = message.CreateReply("Please enter what the correct annotation is.");
                    incorrect = true;
                }
                else // identifying more than 1 annotation
                {
                    reply = message.CreateReply("Please enter just one correct annotation.");
                    incorrect = true;
                }
            }
            else reply = message.CreateReply("Please first ask the bot about the image.");
            await connector.Conversations.ReplyToActivityAsync(reply);
            await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
            await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9)));
            await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
        }

        //////////// BASE API CALLS ////////////
        // returns description using CV API call
        public static async Task<string> Describe(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")));

                ret = analysisResult.Description.Captions[0].Text + "." + messageEnding;
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = userData.GetProperty<Uri>("ImageUrl");
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(imageUri.AbsoluteUri, 1);
                ret = analysisResult.Description.Captions[0].Text + "." + messageEnding;
            }
            return ret;
        }

        // returns primary emotion using Emotion API call
        public static async Task<string> Emotion(Activity message)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")));
                ret = GetEmotion(emotionResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(userData.GetProperty<Uri>("ImageUrl").ToString());
                ret = GetEmotion(emotionResult);
            }
            return ret;
        }

        // gets percentages of specified emotions
        public static async Task<string> Emotion(Activity message, Collection<string> emotions)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            foreach (string emotion in emotions)
            {
                if (null == ValidEmo(emotion)) return (emotion + " is not a valid option. Valid emotions are anger, contempt, disgust, fear, happiness, neutral, sadness, and surprise. Please try again.");
            }
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")));
                StringBuilder sb = new StringBuilder();
                foreach (string emotion in emotions) sb.Append(GetEmotion(emotionResult, ValidEmo(emotion)));
                return sb.Append(messageEnding).ToString();
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(userData.GetProperty<Uri>("ImageUrl").ToString());
                StringBuilder sb = new StringBuilder();
                foreach (string emotion in emotions) sb.Append(GetEmotion(emotionResult, ValidEmo(emotion)));
                return sb.Append(messageEnding).ToString();
            }
            return ret + messageEnding;
        }

        // returns number of faces using Emotion API call
        public static async Task<string> Face(Activity message)
        {
            EmotionServiceClient emotionServiceClient = new EmotionServiceClient(KeyEmo);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")));
                ret = "There are " + emotionResult.Length + " faces." + messageEnding;
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Emotion[] emotionResult = await emotionServiceClient.RecognizeAsync(userData.GetProperty<Uri>("ImageUrl").ToString());
                ret = "There are " + emotionResult.Length + " faces." + messageEnding;
            }
            return ret;
        }

        // returns age of people using CV API call
        public static async Task<string> Age(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")), visualFeatures);
                ret = GetAge(analysisResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = userData.GetProperty<Uri>("ImageUrl");
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, visualFeatures);
                ret = GetAge(analysisResult);
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
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")), null, new string[] { "celebrities" });
                ret = GetCeleb(analysisResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = userData.GetProperty<Uri>("ImageUrl");
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, null, new string[] { "celebrities" });
                ret = GetCeleb(analysisResult);
            }
            return ret;
        }

        // returns gender using CV API
        public static async Task<string> Gender(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")), visualFeatures);
                ret = GetGender(analysisResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = userData.GetProperty<Uri>("ImageUrl");
                VisualFeature[] visualFeatures = new VisualFeature[] { VisualFeature.Faces };
                AnalysisResult analysisResult = await VisionServiceClient.AnalyzeImageAsync(imageUri.AbsoluteUri, visualFeatures);
                ret = GetGender(analysisResult);
            }
            return ret;
        }

        // returns OCR using CV API
        public static async Task<string> Text(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            string ret = "Please first attach an image or enter an image URL.";
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                OcrResults analysisResult = await VisionServiceClient.RecognizeTextAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")));
                ret = GetText(analysisResult);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = userData.GetProperty<Uri>("ImageUrl");
                OcrResults analysisResult = await VisionServiceClient.RecognizeTextAsync(imageUri.AbsoluteUri);
                ret = GetText(analysisResult);
            }
            return ret;
        }

        // returns translation of text within a message to a specified language using Microsoft Translator API call
        public static async Task<string> Translator(Activity message, string to)
        {
            string text = await Text(message);
            string ret = text;
            if (ret.Contains("No text detected") || ret.Contains("Please first attach")) return ret;
            else
            {
                text = text.Replace("The text says", " ").Replace("." + messageEnding, " ");
                text = text.Trim();
                AccessToken admToken;
                string headerValue;
                TranslateAuthentication admAuth = new TranslateAuthentication(IdTrans, SecTrans);
                admToken = admAuth.Token;
                headerValue = "Bearer " + admToken.access_token;
                string langTo = Translate.CheckLanguage(headerValue, to);

                if (langTo == null) ret = "Not a valid language name. Try again.";
                else
                {
                    StringBuilder sb = new StringBuilder().Append("The translation is " + Translate.TranslateMethod(headerValue, text, langTo));
                    if (ret[ret.Length - 1] != '.') sb.Append('.');
                    sb.Append("" + messageEnding);
                    ret = sb.ToString();
                }
            }
            return ret;
        }

        // method that returns activity that displays similar images in a carousel
        public static async Task<Activity> Similar(Activity message)
        {
            VisionServiceClient VisionServiceClient = new VisionServiceClient(KeyDes);
            if (userData.GetProperty<int>("Attachment") == 11)
            {
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(await AttachmentStream(message, userData.GetProperty<Uri>("ImageUrl")), 1);
                if (message.ChannelId.Equals("facebook")) return await FacebookCarousel(message, analysisResult.Description.Captions[0].Text);
                else return await CreateCarousel(message, analysisResult.Description.Captions[0].Text);
            }
            else if (userData.GetProperty<int>("Attachment") == 22)
            {
                Uri imageUri = userData.GetProperty<Uri>("ImageUrl");
                AnalysisResult analysisResult = await VisionServiceClient.DescribeAsync(imageUri.AbsoluteUri, 1);
                if (message.ChannelId.Equals("facebook")) return await FacebookCarousel(message, analysisResult.Description.Captions[0].Text);
                else return await CreateCarousel(message, analysisResult.Description.Captions[0].Text);
            }
            return message.CreateReply("Please first attach an image and enter an image URL.");
        }

        //////////// API HELPERS ////////////
        // helper method that calculates primary emotion
        public static string GetEmotion(Emotion[] emotionResult)
        {
            string ret = "There is no emotion detected." + messageEnding;
            float[] sums = new float[8];
            string[] emotions = { "anger", "contempt", "disgust", "fear", "happiness", "neutral", "sadness", "surpise" };
            if (emotionResult != null && emotionResult.Length > 0)
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
                ret = "The primary emotion is " + emotions[Array.IndexOf(sums, sums.Max())] + "." + messageEnding;
            }
            return ret;
        }

        // helper method that checks whether user input is one that is supported
        public static string ValidEmo(string which)
        {
            if (which == null) return null;
            string ret = null;
            string[][] allEmotions = { new string[] { "anger", "angry", "angered" }, new string[] { "contempt", "contemptuous", "contempted" }, new string[]{ "disgust", "disgusted", "disgustedness" }, new string[] { "fear", "scared", "scaredness" },
                                                    new string[] {"happiness", "happy", "joy" }, new string[] {"neutral", "neutrality", "neutralness" }, new string[] {"sadness", "sad", "sorrow" }, new string[] {"surprise", "surprised", "surprisedness" } };
            for (int i = 0; i < allEmotions.GetLength(0); i++)
            {
                for (int k = 0; k < allEmotions[i].Length; k++)
                {
                    if (which.Equals(allEmotions[i][k])) return allEmotions[i][0];
                }
            }
            return ret;
        }

        // helper method that calculates the percentage of a certain emotion
        public static string GetEmotion(Emotion[] emotionResult, string which)
        {
            if (which == null) return null;
            string ret = " There is no emotion detected.";
            float val = 0.0F;
            if (emotionResult != null && emotionResult.Length > 0)
            {
                foreach (Emotion emotion in emotionResult)
                {
                    switch (which.ToLower(CultureInfo.CurrentCulture))
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
                ret = " The level of " + which + " is " + (val / (emotionResult.Length) * 100) + "%.";
            }
            return ret;
        }

        // helper method that calculates ages
        public static string GetAge(AnalysisResult analysisResult)
        {
            string ret = "No person detected." + messageEnding;
            if (analysisResult != null && analysisResult.Faces.Length == 1)
            {
                ret = "The person's age is " + analysisResult.Faces[0].Age + " years old." + messageEnding;
            }
            else if (analysisResult != null && analysisResult.Faces.Length > 1)
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

        // helper method that calculates which celebrities are present
        public static string GetCeleb(AnalysisResult analysisResult)  // need to sort by lefts
        {
            string ret = "No celebrity detected." + messageEnding;
            if (analysisResult != null && null != analysisResult.Categories && analysisResult.Categories.Length > 0 && analysisResult.Categories[0].Name.Contains("people") && analysisResult.Categories[0].Detail.ToString().Length > 25) // based on number of characters
            {
                string total = analysisResult.Categories[0].Detail.ToString();
                int start = 0;
                List<string> names = new List<string>();
                while (total.IndexOf("name", start, StringComparison.CurrentCulture) != -1)
                {
                    start = total.IndexOf("name", start, StringComparison.CurrentCulture) + 8;
                    int len = total.IndexOf(",", start, StringComparison.CurrentCulture) - start - 1;
                    names.Add(total.Substring(start, len));
                }
                if (names.Count == 1) ret = "This person is [" + names[0] + "](http://en.wikipedia.org/wiki/" + ReplaceSpace(names[0]) + ")." + messageEnding;
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
                    sb.Append("" + messageEnding);
                    ret = sb.ToString();
                }

            }
            return ret;
        }

        // replaces spaces with underscores for wikipedia
        public static string ReplaceSpace(string input)
        {
            if (input == null) return null;
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < input.Length; i++)
            {
                if (input[i] == ' ') sb.Append("_");
                else sb.Append(input[i]);
            }
            return sb.ToString();
        }

        // helper method that calculates gender
        public static string GetGender(AnalysisResult analysisResult)
        {
            string ret = "No person detected." + messageEnding;
            if (analysisResult != null && analysisResult.Faces.Length == 1)
            {
                ret = "The person's gender is " + analysisResult.Faces[0].Gender + "." + messageEnding;
            }
            else if (analysisResult != null && analysisResult.Faces.Length > 1)
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

        // helper method that calculates the text
        public static string GetText(OcrResults analysisResult)
        {
            string ret = "No text detected." + messageEnding;
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
                sb.Append("" + messageEnding);
                ret = sb.ToString();
            }
            return ret;
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

        //////////// GENERAL ACTIVITY HELPERS ////////////
        // general method to set userData and send reply message
        public static async Task SetDataSendMessage(Activity message, Collection<Activity> replies, ConnectorClient connector)
        {
            userData.SetProperty<string>("PreviousQ", message.Text);
            foreach (Activity reply in replies) await connector.Conversations.ReplyToActivityAsync(reply);
            await Task.Run(async () => await SaveMessage(message, message.Timestamp.ToString().Substring(0, 9))); // log incoming message
            foreach (Activity reply in replies) await Task.Run(async () => await SaveMessage(reply, message.Timestamp.ToString().Substring(0, 9))); // log outgoing message
            await stateClient.BotState.SetUserDataAsync(message.ChannelId, message.From.Id, userData);
        }

        // converts attachment url to a stream
        public static async Task<Stream> AttachmentStream(Activity message, Uri url)
        {
            if (message.ChannelId.Equals("skype")) return new MemoryStream(await SkypeMessage(message, url));
            else return new MemoryStream(await new WebClient().DownloadDataTaskAsync(url));
        }

        // returns an activity with a button to confirm accuracy of caption
        public static Activity ConfirmButton(Activity message)
        {
            if (message == null) return null;
            confirm = true;
            if (message.ChannelId.Equals("facebook")) return FacebookButton(message);
            return CreateButton(message);
        }

        // helper method to create accuracy confirming button
        public static Activity CreateButton(Activity message) // works for skype (POSTBACK buttons not yet supported), emulator 
        {
            if (message == null) return null;
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

        //////////// AZURE STORAGE ////////////
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
                    if (propertiesM[i].Name.ToLower(CultureInfo.CurrentCulture).Equals(propertiesMC[k].Name.ToLower(CultureInfo.CurrentCulture)))
                    {
                        var value = propertiesM[i].GetValue(message);
                        propertiesMC[k].SetValue(output, value);
                    }
                }
            }
            output.UserData = new UserData();
            if (userData != null)
            {
                if (userData.GetProperty<string>("Annotation") != null) output.UserData.Annotation = userData.GetProperty<string>("Annotation");
                if (userData.GetProperty<int>("Attachment") > 10) output.UserData.Attachment = userData.GetProperty<int>("Attachment");
                if (userData.GetProperty<Uri>("ImageUrl") != null) output.UserData.ImageUrl = userData.GetProperty<Uri>("ImageUrl");
                if (userData.GetProperty<string>("PreviousQ") != null) output.UserData.PreviousQ = userData.GetProperty<string>("PreviousQ");
            }
            return JsonConvert.SerializeObject(output, Formatting.Indented);
        }

        //////////// SKYPE SPECIFIC HELPERS ////////////
        // processes skype attachment url
        public static async Task<byte[]> SkypeMessage(Activity activity, Uri url)
        {
            using (var connectorClient = new ConnectorClient(new Uri(activity.ServiceUrl)))
            {
                var token = await (connectorClient.Credentials as MicrosoftAppCredentials).GetTokenAsync();
                using (var httpClient = new HttpClient())
                {
                    httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
                    httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/octet-stream"));

                    byte[] ret = await httpClient.GetByteArrayAsync(url);
                    return ret;
                }
            }
        }

<<<<<<< HEAD
        // converts message text to URL for skype
        public static Uri SkypeUrl(string text) // gets image url from skype message
=======
        // helper method to create accuracy confirming button
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Globalization", "CA1303:Do not pass literals as localized parameters", MessageId = "Microsoft.Bot.Connector.Activity.CreateReply(System.String,System.String)")]
        public static Activity CreateButton(Activity message) // works for skype (POSTBACK buttons not yet supported), emulator 
>>>>>>> refs/remotes/MSRCCS/master
        {
            if (text == null) return null;
            string full = text.Substring(text.IndexOf('>'));
            return new Uri(full.Substring(1, full.Length - 5));
        }

        //////////// FACEBOOK HELPERS ////////////
        // helper method to create accuracy confirming button
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Globalization", "CA1303:Do not pass literals as localized parameters", MessageId = "ImageDescriberV3.Payload.set_Text(System.String)")]
        public static Activity FacebookButton(Activity input) // works for facebook
        {
            if (input == null) return null;
            Activity reply = input.CreateReply("");
            FacebookMessage message = new FacebookMessage();
            message.NotificationType = "REGULAR";
            message.Attachment = new Attachments();
            message.Attachment.TypeOfAttachment = "template";
            message.Attachment.Payload = new Payload();
            message.Attachment.Payload.TemplateType = "button";
            message.Attachment.Payload.Text = "Is this correct?";
            message.Attachment.Payload.Buttons.Add(new Button("postback", "postbackyes", "Yes")); // correct caption
            message.Attachment.Payload.Buttons.Add(new Button("postback", "postbackno", "No")); // incorrect caption
            reply.ChannelData = message;
            return reply;
        }

        // helper method that creates similar image carousel
        public static async Task<Activity> FacebookCarousel(Activity input, string query) // for facebook
        {
            Activity reply = input.CreateReply("");
            FacebookMessage message = new FacebookMessage();
            message.NotificationType = "REGULAR";
            message.Attachment = new Attachments();
            message.Attachment.TypeOfAttachment = "template";
            message.Attachment.Payload = new Payload();
            message.Attachment.Payload.TemplateType = "generic";
            JObject json = await SimilarPictures(query);
            message.Attachment.Payload.Elements = new Collection<Element>();
            for (int i = 0; i < 5; i++) message.Attachment.Payload.Elements.Add(new Element((json["value"][i]["name"]).ToString(), (new Uri((json["value"][i]["contentUrl"]).ToString()))));
            reply.ChannelData = message;
            return reply;
        }
    }
}