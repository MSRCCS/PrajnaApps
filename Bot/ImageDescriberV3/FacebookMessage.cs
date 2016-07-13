using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace ImageDescriberV3
{
    // class for representing Facebook rich media attachments
    public class FacebookMessage
    {
        public string notification_type;
        public Attachments attachment = new Attachments();
    }
    public class Attachments
    {
        public string type;
        public Payload payload = new Payload();
    }
    public class Payload
    {
        public string template_type;
        public string text;
        public List<Button> buttons;
        public List<Element> elements;
    }
    public class Element
    {
        public Element (string title, string image_url)
        {
            this.title = title;
            this.image_url = image_url;
        }
        public string title;
        public string image_url;
        public string item_url;
        public string subtitle;
        public List<Button> buttons;
    }
    public class Button
    {
        public Button (string type, string payload, string title)
        {
            this.type = type;
            this.payload = payload;
            this.title = title;
        }
        public string type;
        public string url;
        public string title;
        public string payload;
    }

}