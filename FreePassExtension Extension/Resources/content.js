// content.js
// Runs inside the webpage

console.log("FreePass Content Script Loaded");

function executeAutofill(username, password, shouldSubmit = false) {
    let filled = false;
    let formsToSubmit = [];

    // Very basic heuristic implementation finding password type fields
    const passFields = document.querySelectorAll('input[type="password"]');
    if (passFields.length > 0) {
        passFields.forEach(pf => {
            pf.value = password;
            pf.dispatchEvent(new Event("input", { bubbles: true })); // Trigger react/vue state updates

            // Try to find the username field nearby
            const form = pf.closest('form');
            if (form) {
                const textFields = form.querySelectorAll('input[type="text"], input[type="email"], input:not([type])');
                for (let tf of textFields) {
                    // Guess that the first visible text input before the password is the username
                    tf.value = username;
                    tf.dispatchEvent(new Event("input", { bubbles: true }));
                    filled = true;
                    break;
                }
                if (shouldSubmit) {
                    formsToSubmit.push(form);
                }
            }
            filled = true;
        });
    }

    if (shouldSubmit && formsToSubmit.length > 0) {
        // Wait a brief moment to allow JS frameworks (React/Vue) to register the new input values
        setTimeout(() => {
            formsToSubmit.forEach(form => {
                // Find a submit button
                let submitBtn = form.querySelector('button[type="submit"], input[type="submit"]');

                // Fallback heuristic: Try finding a button with common login text
                if (!submitBtn) {
                    const buttons = form.querySelectorAll('button, input[type="button"]');
                    for (let btn of buttons) {
                        const txt = (btn.innerText || btn.value || "").toLowerCase();
                        if (txt.includes("log ") || txt.includes("login") || txt.includes("sign in") || txt.includes("signin") || txt.includes("submit") || txt.includes("continue")) {
                            submitBtn = btn;
                            break;
                        }
                    }
                }

                if (submitBtn) {
                    submitBtn.click();
                } else {
                    // Final fallback: try to call form.submit() directly
                    try {
                        form.submit();
                    } catch (e) {
                        console.log("Could not auto-submit form.");
                    }
                }
            });
        }, 300);
    }

    return filled;
}

// 1. Immediately on page load, check if the Native App has flagged this page for instant auto-fill
chrome.runtime.sendMessage({ action: "checkAutoFillOnLoad" }).then((response) => {
    if (response && response.shouldAutoFill && response.accounts && response.accounts.length > 0) {
        console.log("FreePass: Auto-filling immediately from FreePass App intent!");
        // We might need a tiny delay for frameworks like layout updates
        setTimeout(() => {
            executeAutofill(response.accounts[0].username, response.accounts[0].password, true);
        }, 500);
    }
});

// 2. Listen for manual autofill clicks from the Safari popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "AutofillCredentials") {
        let filled = executeAutofill(request.username, request.password, true);
        sendResponse({ success: filled });
    }
});
