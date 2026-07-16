import ballerina/http;
import ballerina/log;

// The request we expect from your frontend or Postman
type PromptRequest record {|
    string user_message;
|};

// Insert your newly generated Gemini API key here
configurable string geminiApiKey = ?;

// Using port 9090 as we established earlier!
service /api/v1 on new http:Listener(9090) {

    resource function post chat(@http:Payload PromptRequest payload) returns json|error {
        
        log:printInfo("Sending prompt to Gemini: " + payload.user_message);

        // 1. Initialize the HTTP Client pointing to Google's generative AI servers
        http:Client geminiClient = check new ("https://generativelanguage.googleapis.com");

        // 2. Construct the exact JSON payload the Gemini API expects
        json geminiPayload = {
            "contents": [{
                "parts": [{"text": payload.user_message}]
            }]
        };

        // 3. Make the POST request to the Gemini 1.5 Flash model
        string path = "/v1beta/models/gemini-1.5-flash:generateContent?key=" + geminiApiKey;
        json geminiResponse = check geminiClient->post(path, geminiPayload);

        // 4. Extract the actual text reply from the massive JSON response Gemini sends back
        json extractedText = check geminiResponse.candidates[0].content.parts[0].text;

        // 5. Return our clean, structured response to the user
        json finalResponse = {
            status: "success",
            agent_reply: extractedText
        };

        return finalResponse;
    }
}