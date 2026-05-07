// FreePass background script.
//
// All credential lookups go to the FreePass app's localhost IPC server. That
// server requires a Bearer token, provisioned by the main app and exposed to
// us through the SafariWebExtensionHandler running in our extension's process.
// We fetch the current token via native messaging on every request — the
// handler reads it from the shared keychain in microseconds, and avoiding a
// local cache means the token automatically follows any rotation by the app.

const SERVER_URL = "http://127.0.0.1:54321/";

async function getToken() {
    try {
        const response = await browser.runtime.sendNativeMessage(
            "com.freepass.app.FreePassExtension.Extension",
            { command: "get_token" }
        );
        return response?.token ?? null;
    } catch (e) {
        console.error("FreePass: native messaging failed:", e);
        return null;
    }
}

async function fetchCredentials(domain) {
    const token = await getToken();
    const res = await fetch(`${SERVER_URL}?domain=${encodeURIComponent(domain)}`, {
        headers: token ? { "Authorization": "Bearer " + token } : {}
    });
    if (!res.ok) {
        throw new Error(`FreePass IPC returned ${res.status}`);
    }
    return res.json();
}

browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "getCredentialsFromNativeApp" || request.action === "checkAutoFillOnLoad") {

        let urlDomain = "";
        try {
            const rawUrl = request.url || (sender.tab ? sender.tab.url : "");
            urlDomain = new URL(rawUrl).hostname;
        } catch (e) { /* ignore — domain stays empty */ }

        fetchCredentials(urlDomain)
            .then((data) => sendResponse(data))
            .catch((error) => {
                console.error("FreePass IPC error:", error);
                sendResponse({
                    error: "Failed to connect to FreePass. Make sure the FreePass app is running and unlocked.",
                    accounts: []
                });
            });

        return true; // keep the channel open for the async response
    }
});
