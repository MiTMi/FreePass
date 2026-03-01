document.addEventListener("DOMContentLoaded", () => {
    // 1. Find out which tab we are currently actively viewing
    browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
        let currentTab = tabs[0];

        // 2. Ask the background script to talk to the Native App and get credentials for this URL
        document.getElementById("status").innerText = "Loading from Mac App...";
        document.getElementById("status").style.display = "block";

        browser.runtime.sendMessage({
            action: "getCredentialsFromNativeApp",
            url: currentTab.url
        }).then((response) => {
            document.getElementById("status").style.display = "none";

            if (response && response.accounts && response.accounts.length > 0) {
                renderAccounts(response.accounts, currentTab.id);
            } else {
                document.getElementById("status").innerText = "No passwords found for this site.";
                document.getElementById("status").style.display = "block";
            }
        });
    });
});

function renderAccounts(accounts, tabId) {
    const list = document.getElementById("accounts-list");

    accounts.forEach(acc => {
        const div = document.createElement("div");
        div.className = "account";
        div.innerHTML = `<div class='username'>${acc.username}</div><div class='title'>${acc.title}</div>`;

        div.onclick = () => {
            // Tell the content script running on the page to physically inject these
            browser.tabs.sendMessage(tabId, {
                action: "AutofillCredentials",
                username: acc.username,
                password: acc.password
            }).then(() => {
                window.close(); // hide popup after filling
            });
        };
        list.appendChild(div);
    });
}
