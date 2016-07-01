using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Web;
using Microsoft.Bot;
using Microsoft.Bot.Connector;

namespace ImageDescriber
{
    [DataContract]
    public class MessageClass
    {
        [DataMember]
        public IList<Attachment> attachments = new List<Attachment>();
        [DataMember]
        public object botConversationData;
        [DataMember]
        public object botPerUserInConversationData;
        [DataMember]
        public object botUserData;
        [DataMember]
        public string channelConversationId;
        [DataMember]
        public object channelData;
        [DataMember]
        public string channelMessageId;
        [DataMember]
        public string conversationId;
        [DataMember]
        public DateTime? created;
        [DataMember]
        public string eTag;
        [DataMember]
        public ChannelAccount from = new ChannelAccount();
        [DataMember]
        public IList<string> hashtags = new List<string>();
        [DataMember]
        public string id;
        [DataMember]
        public string language;
        [DataMember]
        public Location location = new Location();
        [DataMember]
        public IList<ChannelAccount> participants = new List<ChannelAccount>();
        [DataMember]
        public IList<Mention> mentions = new List<Mention>();
        [DataMember]
        public string place;
        [DataMember]
        public string replyToMessageId;
        [DataMember]
        public string sourceLanguage;
        [DataMember]
        public string sourceText;
        [DataMember]
        public string text;
        [DataMember]
        public ChannelAccount to = new ChannelAccount();
        [DataMember]
        public int totalParticipants;
        [DataMember]
        public string type;
    }
}
