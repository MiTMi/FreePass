// content.js
// Runs inside the webpage

console.log("FreePass Content Script Loaded");

// --- Autofill Executor ---
function executeAutofill(username, password, shouldSubmit = false) {
    let filled = false;
    let formsToSubmit = [];

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
    } else {
        // Just look for username fields if no password field
        const textFields = document.querySelectorAll('input[type="text"], input[type="email"]');
        for (let tf of textFields) {
            const name = (tf.name || tf.id || "").toLowerCase();
            if (name.includes("user") || name.includes("email") || name.includes("login")) {
                tf.value = username;
                tf.dispatchEvent(new Event("input", { bubbles: true }));
                filled = true;
                break;
            }
        }
    }

    if (shouldSubmit && formsToSubmit.length > 0) {
        setTimeout(() => {
            formsToSubmit.forEach(form => {
                let submitBtn = form.querySelector('button[type="submit"], input[type="submit"]');
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
                    try { form.submit(); } catch (e) { console.log("Could not auto-submit form."); }
                }
            });
        }, 300);
    }
    return filled;
}

// --- Injected UI Styling ---
const iconSvg = `url('data:image/svg+xml;utf8,<svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22Z" fill="%23007AFF"/><path fill-rule="evenodd" clip-rule="evenodd" d="M12 6.5C10.067 6.5 8.5 8.067 8.5 10V11H8C7.4477 11 7 11.4477 7 12V16.5C7 17.3284 7.67157 18 8.5 18H15.5C16.3284 18 17 17.3284 17 16.5V12C17 11.4477 16.5523 11 16 11H15.5V10C15.5 8.067 13.933 6.5 12 6.5ZM10.5 10V11H13.5V10C13.5 9.17157 12.8284 8.5 12 8.5C11.1716 8.5 10.5 9.17157 10.5 10ZM12 15C12.5523 15 13 14.5523 13 14C13 13.4477 12.5523 13 12 13C11.4477 13 11 13.4477 11 14C11 14.5523 11.4477 15 12 15Z" fill="white"/></svg>')`;

function setupInlineIcons() {
    const inputs = document.querySelectorAll('input[type="password"], input[type="email"], input[type="text"]');
    
    inputs.forEach(input => {
        // Skip hidden or already processed inputs
        if (input.dataset.freepassInjected || input.type === 'hidden' || window.getComputedStyle(input).display === 'none') {
            return;
        }
        
        // Target specific credential fields heuristics
        const type = input.type.toLowerCase();
        const name = (input.name || input.id || "").toLowerCase();
        const placeholder = (input.placeholder || "").toLowerCase();
        
        const isLikelyCreds = type === "password" || 
                              type === "email" || 
                              name.includes("user") || 
                              name.includes("login") || 
                              name.includes("email") ||
                              placeholder.includes("email") ||
                              placeholder.includes("username");
        
        if (!isLikelyCreds) return;
        
        input.dataset.freepassInjected = "true";

        // Create a wrapper to nicely hold both the input and the inline absolute-positioned icon
        const wrapper = document.createElement("div");
        wrapper.style.position = "relative";
        wrapper.style.display = window.getComputedStyle(input).display === "block" ? "block" : "inline-block";
        wrapper.style.width = input.style.width || "100%"; 
        wrapper.style.margin = input.style.margin;
        wrapper.className = "freepass-input-wrapper";
        
        input.parentNode.insertBefore(wrapper, input);
        wrapper.appendChild(input);

        // Adjust input margins manually if needed so the wrapper bounds it securely
        input.style.margin = "0";

        const iconBtn = document.createElement("div");
        iconBtn.style.position = "absolute";
        iconBtn.style.right = "10px";
        iconBtn.style.top = "50%";
        iconBtn.style.transform = "translateY(-50%)";
        iconBtn.style.width = "20px";
        iconBtn.style.height = "20px";
        iconBtn.style.backgroundImage = iconSvg;
        iconBtn.style.backgroundSize = "contain";
        iconBtn.style.backgroundRepeat = "no-repeat";
        iconBtn.style.backgroundPosition = "center";
        iconBtn.style.cursor = "pointer";
        iconBtn.style.zIndex = "999";
        iconBtn.style.opacity = "0.7";
        iconBtn.style.transition = "opacity 0.2s, transform 0.2s";

        iconBtn.addEventListener("mouseenter", () => {
            iconBtn.style.opacity = "1";
            iconBtn.style.transform = "translateY(-50%) scale(1.1)";
        });
        
        iconBtn.addEventListener("mouseleave", () => {
            iconBtn.style.opacity = "0.7";
            iconBtn.style.transform = "translateY(-50%) scale(1)";
        });

        iconBtn.addEventListener("click", (e) => {
            e.preventDefault();
            e.stopPropagation();
            showSelectorPopover(iconBtn);
        });

        wrapper.appendChild(iconBtn);
    });
}

function showSelectorPopover(anchorEl) {
    // Remove if exists
    const existing = document.getElementById("freepass-inline-popover");
    if (existing) {
        existing.remove();
        return; // act as a toggle if clicking the same icon again
    }

    chrome.runtime.sendMessage({ action: "getCredentialsFromNativeApp", url: window.location.href }).then((response) => {
        if (!response || !response.accounts || response.accounts.length === 0) {
            showTooltip(anchorEl, "No FreePass logins found for this site.");
            return;
        }

        const popover = document.createElement("div");
        popover.id = "freepass-inline-popover";
        popover.style.position = "absolute";
        popover.style.zIndex = "2147483647";
        popover.style.background = "linear-gradient(135deg, rgba(30, 30, 30, 0.95), rgba(20, 20, 20, 0.95))";
        popover.style.backdropFilter = "blur(10px)";
        popover.style.border = "1px solid rgba(255, 255, 255, 0.1)";
        popover.style.borderRadius = "10px";
        popover.style.boxShadow = "0 8px 32px rgba(0, 0, 0, 0.3)";
        popover.style.padding = "10px";
        popover.style.fontFamily = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
        popover.style.color = "white";
        popover.style.display = "flex";
        popover.style.flexDirection = "column";
        popover.style.gap = "8px";
        popover.style.minWidth = "250px";

        // Calculate Position near the anchorEl
        const rect = anchorEl.getBoundingClientRect();
        popover.style.top = (window.scrollY + rect.bottom + 10) + "px";
        // Attempt to right align with the icon
        popover.style.left = (window.scrollX + rect.right - 250) + "px"; 

        const header = document.createElement("div");
        header.style.fontSize = "11px";
        header.style.fontWeight = "600";
        header.style.color = "rgba(255,255,255,0.6)";
        header.style.textTransform = "uppercase";
        header.style.letterSpacing = "0.5px";
        header.style.marginBottom = "4px";
        header.innerText = "FreePass Logins";
        popover.appendChild(header);

        response.accounts.forEach(acc => {
            const btn = document.createElement("button");
            btn.style.background = "rgba(255,255,255,0.05)";
            btn.style.border = "1px solid rgba(255,255,255,0.1)";
            btn.style.borderRadius = "6px";
            btn.style.padding = "10px 14px";
            btn.style.color = "white";
            btn.style.fontSize = "14px";
            btn.style.textAlign = "left";
            btn.style.cursor = "pointer";
            btn.style.display = "flex";
            btn.style.flexDirection = "column";
            btn.style.transition = "all 0.2s ease";

            const titleLab = document.createElement("span");
            titleLab.innerText = acc.title || new URL(window.location.href).hostname;
            titleLab.style.fontWeight = "600";
            titleLab.style.marginBottom = "2px";
            
            const userLab = document.createElement("span");
            userLab.innerText = acc.username;
            userLab.style.fontSize = "12px";
            userLab.style.color = "rgba(255,255,255,0.7)";

            btn.appendChild(titleLab);
            btn.appendChild(userLab);

            btn.addEventListener("mouseover", () => {
                btn.style.background = "rgba(0,122,255, 0.4)";
                btn.style.borderColor = "rgba(0,122,255, 0.8)";
            });
            btn.addEventListener("mouseout", () => {
                btn.style.background = "rgba(255,255,255,0.05)";
                btn.style.borderColor = "rgba(255,255,255,0.1)";
            });

            btn.addEventListener("click", () => {
                executeAutofill(acc.username, acc.password, false);
                popover.remove();
            });

            popover.appendChild(btn);
        });

        document.body.appendChild(popover);

        // Remove on outside click
        setTimeout(() => {
            document.addEventListener("click", function removePopover(e) {
                if (!popover.contains(e.target)) {
                    popover.remove();
                    document.removeEventListener("click", removePopover);
                }
            });
        }, 100);
    });
}

function showTooltip(anchorEl, text) {
    const tooltip = document.createElement("div");
    tooltip.innerText = text;
    tooltip.style.position = "absolute";
    tooltip.style.zIndex = "2147483647";
    tooltip.style.background = "rgba(0,0,0,0.8)";
    tooltip.style.color = "white";
    tooltip.style.padding = "6px 10px";
    tooltip.style.borderRadius = "6px";
    tooltip.style.fontSize = "12px";
    tooltip.style.pointerEvents = "none";
    
    const rect = anchorEl.getBoundingClientRect();
    tooltip.style.top = (window.scrollY + rect.top - 35) + "px";
    tooltip.style.left = (window.scrollX + rect.left - 50) + "px";
    
    document.body.appendChild(tooltip);
    setTimeout(() => tooltip.remove(), 2500);
}

// Watch the DOM for fields injected dynamically (like React pages or late-rendered modals)
const observer = new MutationObserver((mutations) => {
    // Debounce this to avoid layout thrashing
    setupInlineIcons();
});

// Run once, and start observing natively
setupInlineIcons();
observer.observe(document.body, { childList: true, subtree: true });

// Check immediately on page load to see if a quick auto-fill intent was issued
chrome.runtime.sendMessage({ action: "checkAutoFillOnLoad", url: window.location.href }).then((response) => {
    if (response && response.shouldAutoFill && response.accounts && response.accounts.length > 0) {
        console.log("FreePass: Auto-filling immediately from FreePass App intent!");
        setTimeout(() => {
            executeAutofill(response.accounts[0].username, response.accounts[0].password, true);
        }, 500);
    }
});

// Allow the popup to trigger autofills
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "AutofillCredentials") {
        let filled = executeAutofill(request.username, request.password, true);
        sendResponse({ success: filled });
        return true;
    }
});
