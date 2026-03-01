browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    // Both popup manual requests and automatic content.js pageload checks use this flow
    if (request.action === "getCredentialsFromNativeApp" || request.action === "checkAutoFillOnLoad") {

        let urlDomain = "unknown";
        try {
            // For popup requests, the URL is provided. For pageload, we check sender.tab.url
            let rawUrl = request.url || (sender.tab ? sender.tab.url : "");
            urlDomain = new URL(rawUrl).hostname;
        } catch (e) { }

        // Use fetch() to communicate directly with the FreePass Mac App's newly created local HTTP server
        fetch(`http://127.0.0.1:54321/?domain=${urlDomain}`)
            .then(res => res.json())
            .then(data => {
                sendResponse(data);
            })
            .catch(error => {
                console.error("Local Server Error: ", error);

                // Note for troubleshooting
                sendResponse({
                    error: "Failed to connect to FreePass. Make sure the FreePass app is currently running AND unlocked on your Mac.",
                    accounts: []
                });
            });

        return true; // Keep message channel open for async response
    }
});
