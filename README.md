# AgenteMobile

iPad app that chats with Claude and lets it create, read, and delete documents on the device.

## Setup

1. Enable the repo's git hooks (blocks commits that contain an API key):

   ```sh
   git config core.hooksPath .githooks
   ```

2. Run the app and tap the key icon in the chat header to enter your Anthropic API key.
   It is stored in the device Keychain, never in source code or the app binary.

### Local development

To skip entering the key on the simulator, set `ANTHROPIC_API_KEY` in the Xcode scheme
(Product → Scheme → Edit Scheme → Run → Environment Variables). It overrides the stored key.
For a gitignored place to keep it locally, use `.env`.

Don't commit the scheme with the key in it. Keep the scheme unshared (the default) so it
stays in the ignored `xcuserdata/`.
