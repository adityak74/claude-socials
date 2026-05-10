---
name: threads-post-spoiler
description: Creates and publishes a spoiler-style post to Meta Threads using Playwright browser automation. Trigger when the user says "spoiler post on Threads", "hide this behind a spoiler", "tap to reveal post", "Threads spoiler", or any similar intent to post content that requires a tap to show. Do NOT trigger for regular posts or carousels — those have dedicated skills.
---

# Threads Post - Spoiler

Creates a spoiler-style post on Meta Threads through the web UI using Playwright MCP. This avoids Meta Graph API setup, app review, scoped access tokens, numeric user IDs, and container-publish flows.

Threads web UI support for native tap-to-reveal spoilers may vary by account and rollout. If the composer exposes a spoiler control, use it. If it does not, ask the user whether to publish a text-safe spoiler format instead, such as a warning line followed by spacing and the spoiler content.

## Prerequisites

- Playwright MCP is configured and available to the agent.
- The browser profile used by Playwright is logged in to Threads at `https://www.threads.net/`.
- Any media to upload exists as a local file path the browser can access.

If the browser is not logged in, open Threads with Playwright and ask the user to complete login in the browser. Do not ask for a Meta access token.

## Optional Setup

Skills may use these environment variables when present:

- `THREADS_HANDLE` - the user's public Threads handle, used only for nicer reporting.
- `THREADS_PROFILE_DIR` - a persistent browser profile directory if the local Playwright MCP setup supports it.

Credentials are browser-session based. Do not create or request `THREADS_USER_ID` or `THREADS_ACCESS_TOKEN`.

## Inputs

Ask the user for:

1. **Post content** - the text and/or media to hide.
2. **Spoiler intent** - text spoiler, media spoiler, or both.
3. **Fallback preference** - whether a text-safe spoiler format is acceptable if the web UI has no native spoiler control.

## Crafting the Post

When the user provides content to hide:

- Write a clear teaser or warning line before the spoiler.
- Keep the total post within the visible Threads composer limit.
- Use 1-3 hashtags max at the end when useful.
- Avoid revealing the spoiler in the first visible line.

Show the draft and the intended spoiler behavior to the user for approval before publishing.

## Workflow

### Step 1: Open Threads

Use Playwright MCP to navigate to:

```text
https://www.threads.net/
```

If the login screen appears, stop and ask the user to log in through the browser. After login, continue with the same browser session.

### Step 2: Start a new post

Use Playwright's accessibility snapshot or locator tools to find the composer entry point. Common labels include:

- `New thread`
- `Start a thread`
- `Post`
- `Create`

Open the composer and paste the approved text.

### Step 3: Apply spoiler behavior

Inspect the visible composer controls and menus for spoiler-related options such as:

- `Spoiler`
- `Hide`
- `Mark as spoiler`
- `Sensitive`
- `Content warning`

If a native spoiler control exists, apply it to the approved text/media and verify the UI shows the intended hidden state.

If no native spoiler control exists, stop before publishing and ask whether to use the approved text-safe spoiler fallback.

### Step 4: Attach media if needed

For media spoilers or combined posts, use the upload control and set the approved local file path. Wait for the preview to finish and verify any spoiler/sensitive-media state remains applied.

### Step 5: Publish

Click the final publish button, commonly labeled `Post`, `Publish`, or `Thread`.

Wait until the composer closes and the new post appears, or until Threads shows a confirmation/error state.

### Step 6: Confirm and report

Tell the user:

- Success or failure.
- Whether a native spoiler control or fallback text format was used.
- The live post URL if Playwright can read it from the page or browser address.
- Any visible Threads error message on failure.

Never expose browser cookies, session storage, or other authentication data.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| Login required | Browser session is not authenticated | Ask the user to log in through the Playwright browser |
| Native spoiler control missing | Threads web UI does not expose this feature | Ask before using a text-safe spoiler fallback |
| Upload fails | File path invalid, unsupported media, or upload issue | Ask for a valid local file path or retry once after the preview clears |
| Publish button disabled | Empty text, upload still processing, or validation issue | Wait for upload completion and check visible validation text |
| Rate/limit message | Threads account limit or platform restriction | Report the exact visible message and stop |
| Captcha/checkpoint | Threads security challenge | Ask the user to complete it manually in the browser |

## Important Notes

- This skill uses the Threads web UI, not `graph.threads.net`.
- Do not use curl, API containers, Meta app credentials, or long-lived tokens.
- Native spoiler availability is UI-dependent; do not claim a native spoiler was applied unless Playwright verified it in the composer.
- Prefer visible UI labels and Playwright accessibility locators over brittle CSS selectors.
- Keep the browser profile persistent when possible so the user does not need to log in every run.
