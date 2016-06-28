
**Bot** contains a bot that can chat with user, and identify object in image/video sent by user. The bot is built on the [Microsoft Bot Framework SDK](https://dev.botframework.com/). 

It uses [Microsoft LUIS](https://www.luis.ai/) for interpreting natural language sent by the user. Additionally, the bot uses a few APIs from the Microsoft Cognitive Services Suite. 
* [Computer Vision API](https://www.microsoft.com/cognitive-services/en-us/computer-vision-api) for captioning, description, ages, genders, celebrities, and OCR.
* [Emotion API](https://www.microsoft.com/cognitive-services/en-us/emotion-api) for detecting facial emotion
* [Face API](https://www.microsoft.com/cognitive-services/en-us/face-api) for analysis of faces
 
The bot can be used by running the [bot framework emulator](http://download.botframework.com/botconnector/tools/emulator/publish.htm) and entering in the appropriate App Id and App Secret, found in the Web.config file. 

