// FreePass background script.
//
// All credential lookups go to the FreePass app's localhost IPC server. That
// server requires a Bearer token, provisioned by the main app and exposed to
// us through the SafariWebExtensionHandler running in our extension's process.
// We cache the token in `browser.storage.local` and refresh it on 401.

const SERVER_URL = "http://127.0.0.1:54321/";

async function getToken({ refresh = false } = {}) {
    if (!refresh) {
        const cached = await browser.storage.local.get("ipc_token");
        if (cached && cached.ipc_token) return cached.ipc_token;
    }
    try {
        const response = await browser.runtime.sendNativeMessage("com.freepass.app.FreePassExtension.Extension", { command: "get_token" });
        if (response && response.token) {
            await browser.storage.local.set({ ipc_token: response.token });
            return response.token;
        }
    } catch (e) {
        console.error("FreePass: native messaging failed:", e);
    }
    return null;
}

async function fetchCredentials(domain) {
    let token = await getToken();
    const doFetch = async (bearer) => {
        return fetch(`${SERVER_URL}?domain=${encodeURIComponent(domain)}`, {
            headers: bearer ? { "Authorization": "Bearer " + bearer } : {}
        });
    };

    let res = await doFetch(token);
    if (res.status === 401) {
        // Token may have been rotated — refresh from the handler and retry once.
        token = await getToken({ refresh: true });
        if (token) res = await doFetch(token);
    }
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
