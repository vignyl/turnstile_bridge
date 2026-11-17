# turnstile_bridge example

A small app to try [`turnstile_bridge`](../README.md). It uses Cloudflare's test site keys, which work on any hostname, so you don't need a Cloudflare account to run it.

```bash
cd example
flutter run
```

You can switch between the test keys (always passes, always fails, forced interaction), change the theme and size, and try the controller buttons: reset, remove, render, getResponse, destroy and recreate. Every event shows up in a log at the bottom. The last section fetches a token with the invisible test key through `TurnstileHeadless`.
