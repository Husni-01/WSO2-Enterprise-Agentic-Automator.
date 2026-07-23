import ballerina/http;
import ballerina/log;

// The structured request payload expected from Postman or the frontend
type PromptRequest record {|
    string user_message;
|};

// Configurable runtime variable injected securely from your local Config.toml
configurable string geminiApiKey = ?;

// Exposing the service on port 9090
service /api/v1 on new http:Listener(9090) {

    resource function post chat(@http:Payload PromptRequest payload) returns json|error {
        
        log:printInfo("Sending prompt to Gemini 2.5 Flash: " + payload.user_message);

        // 1. Initialize the native HTTP Client
        http:Client geminiClient = check new ("https://generativelanguage.googleapis.com");

        // 2. Construct the JSON payload with Thinking Mode disabled/minimized for lower TTFT
        json geminiPayload = {
            "contents": [{
                "parts": [{"text": payload.user_message}]
            }],
            "generationConfig": {
                "thinkingConfig": {
                    "thinkingBudget": 0 
                }
            }
        };

        // 3. Post to the highly stable Gemini 2.5 Flash endpoint
        string path = "/v1beta/models/gemini-3.1-flash-lite:generateContent?key=" + geminiApiKey;
        json geminiResponse = check geminiClient->post(path, geminiPayload);

        // DEFENSIVE CHECK: Catch API errors gracefully so the server doesn't crash
        map<json> responseMap = check geminiResponse.ensureType();
        if responseMap.hasKey("error") {
            // REMOVED 'check' from this line!
            json errorData = responseMap.get("error"); 
            log:printError("Google API Error: " + errorData.toString());
            
            return {
                status: "failed",
                agent_reply: "The AI provider encountered an issue. Please try again."
            };
        }

        // 4. Safely navigate the JSON by explicitly casting to json[] arrays
        json[] candidates = <json[]> check geminiResponse.candidates;
        json firstCandidate = candidates[0];
        
        json content = check firstCandidate.content;
        json[] parts = <json[]> check content.parts;
        
        json firstPart = parts[0];
        string extractedText = check firstPart.text.ensureType(string);

        // 5. Return the clean, unified response wrapper back to the client
        json finalResponse = {
            status: "success",
            agent_reply: extractedText
        };

        return finalResponse;
    }
}