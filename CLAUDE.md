# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & run

```bash
# Build the app (Debug, native arch). Always specify the macOS destination.
xcodebuild -project FreePass.xcodeproj -scheme FreePass -configuration Debug -destination 'platform=macOS' build

# Quiet build that surfaces only diagnostics:
xcodebuild -project FreePass.xcodeproj -scheme FreePass -destination 'platform=macOS' build 2>&1 | grep -E "warning:|error:"

# Regenerate the .xcodeproj from project.yml (only needed if you add/move source files):
xcodegen generate
```

The `.xcodeproj` is tracked (see [.gitignore](.gitignore) — it's intentional for portability). `project.yml` is the source of truth for target structure; if you add a Swift file outside an existing tracked directory, run `xcodegen generate`.

There is no test target. Don't add one without asking — the user has explicitly kept this app test-light.

## Target topology

Three targets, defined in [project.yml](project.yml):

1. **`FreePass`** (`com.freepass.app`) — the SwiftUI macOS app. Sandboxed, hardened runtime, deployment target macOS 14, Swift 6.
2. **`FreePassExtension`** (`com.freepass.app.FreePassExtension`) — the Safari container app for the web extension. Mostly stock Apple template; rarely touched.
3. **`FreePassExtension Extension`** (`com.freepass.app.FreePassExtension.Extension`) — the Safari Web Extension itself. Contains the `SafariWebExtensionHandler` (Swift) and the JS bundle in `Resources/`.

Note the literal space in `FreePassExtension Extension/` — quote the path in shell commands.

## Cryptographic contract

If you touch anything in [FreePass/Security/](FreePass/Security/) or `AppState`'s key handling, treat the following as load-bearing:

- **KDF**: PBKDF2-SHA256, 600 000 iterations, 32-byte salt → 32-byte `SymmetricKey` ([KeyDerivation.swift](FreePass/Security/KeyDerivation.swift)). Don't lower the iteration count.
- **AEAD**: AES-256-GCM via `CryptoKit`, combined-form (nonce ‖ ciphertext ‖ tag) ([CryptoManager.swift](FreePass/Security/CryptoManager.swift)). Every encrypted blob in `VaultItem` is a self-contained sealed box.
- **Verification hash**: HMAC-SHA256 of the literal string `FreePass_MasterKey_Verification` under the derived key. Compared with `constantTimeEqual` on unlock — keep it that way.
- **Keychain layout** ([KeychainManager.swift](FreePass/Security/KeychainManager.swift)):
  - Service `com.freepass.app` for vault items: `master_salt`, `verification_hash`, `biometric_derived_key`.
  - Shared access group `$(AppIdentifierPrefix)com.freepass.app` for the IPC bearer token only. Both the main app and the extension declare this group in their entitlements; the extension reads the token from it.
  - Service `com.freepass.app.dev` is read-only legacy. `load(for:)` will lazily migrate `salt` / `verificationHash` / `biometricKey` from it on first read. Don't write to the legacy service.

### What's encrypted vs. what's metadata

In [VaultItem.swift](FreePass/Models/VaultItem.swift), a `VaultItem` mixes encrypted blobs (`encryptedPassword`, `encryptedNotes`, `encryptedCardNumber/Expiration/CVV`, `encryptedFields`) with **plaintext metadata** (`title`, `username`, `url`, `category`, timestamps, flags). The re-keying flow in `AppState.changeMasterPassword` exploits this: if a sealed box can't be decrypted under the current key (e.g. partial corruption or a stale biometric key), the metadata survives and the user is offered a "force clear" recovery path.

Per-category extra fields are stored as an AES-GCM-sealed JSON `[String: String]` in `encryptedFields`. The schema for each category lives in `VaultCategory.fieldSpecs` ([VaultItem.swift:23](FreePass/Models/VaultItem.swift#L23)).

## App state & lifecycle

`AppState` ([FreePass/Models/AppState.swift](FreePass/Models/AppState.swift)) is a `@MainActor`, `@Observable` singleton injected via SwiftUI's `.environment(appState)`. It owns:

- `derivedKey: SymmetricKey?` — the in-memory unlock key. `nil` ⇒ vault locked.
- The inactivity auto-lock timer, driven by an `NSEvent` global monitor (real user input, not unlock time).
- The four auth-success entry points: `setupMasterPassword`, `unlock(with:)`, `unlockWithBiometrics()`, `changeMasterPassword`. **Every one of them must call `rotateExtensionTokenAfterAuth()`** before returning success — see "Safari extension IPC" below.

`changeMasterPassword` follows a 3-phase commit (compute new ciphertexts → apply in memory → write Keychain). The Keychain write is last; if it fails, every in-memory mutation is rolled back and the old salt/hash are restored. Preserve this ordering if you refactor it.

## Safari extension IPC

The extension talks to the running app over loopback HTTP. There is no XPC, no app-group file. Wire diagram:

```
background.js ──HTTP+Bearer──▶ 127.0.0.1:54321 (NWListener in main app)
     ▲                                  │
     │ get_token (native message)       │ shared keychain
     └─ SafariWebExtensionHandler ──────┘
```

- **Server**: `ExtensionServer` in [FreePass/Views/ContentView.swift](FreePass/Views/ContentView.swift) — yes, in `ContentView.swift`. It's a `@unchecked Sendable` singleton bound to the main queue. `isLoopback()` rejects non-loopback connections; bearer auth uses constant-time compare.
- **Token**: 32 random bytes in the shared keychain group, fetched lazily by `KeychainManager.ensureIPCToken()` and rotated by `KeychainManager.rotateIPCToken()` after every auth event. The server caches it in `tokenCache`; `ExtensionServer.shared.updateTokenCache(_:)` keeps that cache in sync with rotation.
- **Extension**: [background.js](FreePassExtension%20Extension/Resources/background.js) caches the token in `browser.storage.local` and has a 401-refresh path. Rotation works because of this refresh path — don't remove it.
- **Domain matching**: `DomainMatcher` in `ContentView.swift` — exact host match or labelled-suffix match (`.example.com`). Substring matches are deliberately rejected so `evil-paypal.com` won't match `paypal.com`.
- **Autofill handshake**: when the user clicks "Open & Fill" in the app, [VaultDetailView.swift](FreePass/Views/VaultDetailView.swift) sets `ExtensionServer.shared.pendingAutoFillDomain`; the next IPC request from that domain returns `shouldAutoFill: true` once and clears the flag.

## Conventions worth knowing

- The colour palette and reusable view modifiers (`fpTextField`, `FPGradientButtonStyle`, `Color.fpBackground`, etc.) live in [FreePass/Theme/Theme.swift](FreePass/Theme/Theme.swift). Use those rather than inlining colours.
- New vault categories: add to `VaultCategory` enum, then add `fieldSpecs` and (if needed) `subtitleFieldKey` in the same file. The Add/Edit UI ([AddEditItemView.swift](FreePass/Views/AddEditItemView.swift), [AddEditItemSupport.swift](FreePass/Views/AddEditItemSupport.swift)) reads the spec dynamically.
- `AppState` writes verbose `print()` to stdout for non-fatal failures (Touch ID enrollment, IPC token rotation, etc.). Match that style — these are diagnostic breadcrumbs, not errors that should propagate to the UI.
