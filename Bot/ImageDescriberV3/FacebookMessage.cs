using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;

namespace ImageDescriberV3
{
    // class for representing Facebook rich media attachments
    public class FacebookMessage
    {
        [JsonProperty(PropertyName = "notification_type")]
        public string NotificationType { get; set; }

        [JsonProperty(PropertyName = "attachment")]
        public Attachments Attachment { get; set; }
    }

    public class Attachments
    {
        [JsonProperty(PropertyName = "type")]
        public string TypeOfAttachment { get; set; }

        [JsonProperty(PropertyName = "payload")]
        public Payload Payload { get; set; }
    }
    public class Payload
    {
        [JsonProperty(PropertyName = "template_type")]
        public string TemplateType { get; set; }

        [JsonProperty(PropertyName = "text")]
        public string Text { get; set; }

        [JsonProperty(PropertyName = "buttons")]
        internal Collection<Button> Buttons;

        [JsonProperty(PropertyName = "elements")]
        internal Collection<Element> Elements;
    }
    public class Element
    {
        public Element(string title, Uri imageUrl)
        {
            this.Title = title;
            this.ImageUrl = imageUrl;
        }

        [JsonProperty(PropertyName = "title")]
        public string Title { get; set; }

        [JsonProperty(PropertyName = "image_url")]
        public Uri ImageUrl { get; set; }

        [JsonProperty(PropertyName = "item_url")]
        public Uri ItemUrl { get; set; }

        [JsonProperty(PropertyName = "subtitle")]
        public string Subtitle { get; set; }
    }
    public class Button
    {
        public Button(string type, string payload, string title)
        {
            this.TypeOfButton = type;
            this.Payload = payload;
            this.Title = title;
        }

        [JsonProperty(PropertyName = "type")]
        public string TypeOfButton { get; set; }

        [JsonProperty(PropertyName = "url")]
        public Uri Url { get; set; }

        [JsonProperty(PropertyName = "title")]
        public string Title { get; set; }

        [JsonProperty(PropertyName = "payload")]
        public string Payload { get; set; }
    }

}