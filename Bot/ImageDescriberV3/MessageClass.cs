using System;
using System.Collections.Generic;
using Microsoft.Bot.Connector;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Collections;
using System.Linq;

namespace ImageDescriberV3
{
    // class for represeting content of an Activity
    public class MessageClass
    {
        [JsonProperty(PropertyName = "action")]
        public string Action { get; set; }

        [JsonProperty(PropertyName = "attachmentLayout")]
        public string AttachmentLayout { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Usage", "CA2227:CollectionPropertiesShouldBeReadOnly")]
        // Usage of Reflection to assign properties requires them to be able to be set
        [JsonProperty(PropertyName = "attachments")]
        public IList<Attachment> Attachments { get; set; }

        [JsonProperty(PropertyName = "channelData")]
        public object ChannelData { get; set; }

        [JsonProperty(PropertyName = "channelId")]
        public string ChannelId { get; set; }

        [JsonProperty(PropertyName = "conversation")]
        public ConversationAccount Conversation { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Usage", "CA2227:CollectionPropertiesShouldBeReadOnly")]
        [JsonProperty(PropertyName = "entities")]
        internal IList<Entity> Entities { get; set; }

        [JsonProperty(PropertyName = "from")]
        public ChannelAccount From { get; set; }

        [JsonProperty(PropertyName = "historyDisclosed")]
        public bool? HistoryDisclosed { get; set; }

        [JsonProperty(PropertyName = "id")]
        public string Id { get; set; }

        [JsonProperty(PropertyName = "locale")]
        public string Locale { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Usage", "CA2227:CollectionPropertiesShouldBeReadOnly")]
        [JsonProperty(PropertyName = "membersAdded")]
        public IList<ChannelAccount> MembersAdded { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Usage", "CA2227:CollectionPropertiesShouldBeReadOnly")]
        [JsonProperty(PropertyName = "membersRemoved")]
        public IList<ChannelAccount> MembersRemoved { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Usage", "CA2227:CollectionPropertiesShouldBeReadOnly")]
        [JsonExtensionData(ReadData = true, WriteData = true)]
        public JObject Properties { get; set; }

        [JsonProperty(PropertyName = "recipient")]
        public ChannelAccount Recipient { get; set; }

        [JsonProperty(PropertyName = "replyToId")]
        public string ReplyToId { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1056:UriPropertiesShouldNotBeStrings")]
        // Identifier is of type string in Activity class
        [JsonProperty(PropertyName = "serviceUrl")]
        public string ServiceUrl { get; set; }

        [JsonProperty(PropertyName = "summary")]
        public string Summary { get; set; }

        [JsonProperty(PropertyName = "text")]
        public string Text { get; set; }

        [JsonProperty(PropertyName = "textFormat")]
        public string TextFormat { get; set; }

        [JsonProperty(PropertyName = "timestamp")]
        public DateTime? Timestamp { get; set; }

        [JsonProperty(PropertyName = "topicName")]
        public string TopicName { get; set; }

        [JsonProperty(PropertyName = "type")]
        public string Type { get; set; }

        [JsonProperty(PropertyName = "userData")]
        public UserData UserData { get; set; }

    }

    public class UserData
    {

        [JsonProperty(PropertyName = "imageUrl")]
        public Uri ImageUrl { get; set; }

        [JsonProperty(PropertyName = "attachment")]
        public int Attachment { get; set; }

        [JsonProperty(PropertyName = "annotation")]
        public string Annotation { get; set; }

        [JsonProperty(PropertyName = "previousQ")]
        public string PreviousQ { get; set; }
    }

}