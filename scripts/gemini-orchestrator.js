const https = require('https');

const API_KEY = process.env.GEMINI_CLI_TOKEN || process.env.GOOGLE_API_KEY;
if (!API_KEY) {
    console.error('Error: GEMINI_CLI_TOKEN or GOOGLE_API_KEY not set.');
    process.exit(1);
}

const MODEL = process.env.GEMINI_CLI_MODEL || 'google/gemini-2.5-flash';
// Extract model name if it contains provider prefix (e.g. google/gemini-2.5-flash -> gemini-2.5-flash)
const cleanModel = MODEL.replace('google/', '');

// Parse arguments
const args = process.argv.slice(2);
const flags = args.filter(arg => arg.startsWith('--'));
const promptParts = args.filter(arg => !arg.startsWith('--'));
const promptArg = promptParts.join(' ');

if (!promptArg) {
    console.error('Error: No prompt provided.');
    process.exit(1);
}

// Check for --json flag
const isJsonMode = flags.includes('--json');

const payload = {
    contents: [{
        parts: [{ text: promptArg }]
    }],
    generationConfig: {
        temperature: 0.2, // Low temp for deterministic analysis
    }
};

if (isJsonMode) {
    payload.generationConfig.responseMimeType = "application/json";
}

const options = {
    hostname: 'generativelanguage.googleapis.com',
    path: `/v1beta/models/${cleanModel}:generateContent?key=${API_KEY}`,
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
    }
};

const req = https.request(options, (res) => {
    let data = '';

    res.on('data', (chunk) => {
        data += chunk;
    });

    res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
            try {
                const response = JSON.parse(data);
                const content = response.candidates?.[0]?.content?.parts?.[0]?.text;
                if (content) {
                    console.log(content);
                } else {
                    console.error('Error: No content in response', data);
                    process.exit(1);
                }
            } catch (e) {
                console.error('Error parsing response JSON:', e);
                console.error('Response data:', data);
                process.exit(1);
            }
        } else {
            console.error(`Error: API request failed with status ${res.statusCode}`);
            console.error('Response:', data);
            process.exit(1);
        }
    });
});

req.on('error', (error) => {
    console.error('Error calling Gemini API:', error);
    process.exit(1);
});

req.write(JSON.stringify(payload));
req.end();
