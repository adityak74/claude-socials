---
name: threads-post
description: Crafts and publishes a single text or image post to Meta Threads using Playwright browser automation. Trigger when the user says "post to Threads", "share on Threads", "publish this to Threads", "put this on Threads", or any similar intent to post a single piece of content to Threads. Do NOT trigger for carousel (multi-image) posts or reply chain threads — those have dedicated skills.
---

# Threads Post - Single Post

Publishes one text or image post to Meta Threads through the web UI using Playwright MCP. This avoids Meta Graph API setup, app review, scoped access tokens, numeric user IDs, and container-publish flows.

## Prerequisites

- Playwright MCP is configured and available to the agent.
- The browser profile used by Playwright is logged in to Threads at `https://www.threads.net/`.
- Any image to upload exists as a local file path the browser can access.

If the browser is not logged in, open Threads with Playwright and ask the user to complete login in the browser. Do not ask for a Meta access token.

## Optional Setup

Skills may use these environment variables when present:

- `THREADS_HANDLE` - the user's public Threads handle, used only for nicer reporting.
- `THREADS_PROFILE_DIR` - a persistent browser profile directory if the local Playwright MCP setup supports it.

Credentials are browser-session based. Do not create or request `THREADS_USER_ID` or `THREADS_ACCESS_TOKEN`.

## Inputs

- **Article or content** - craft a concise Threads post from it.
- **Ready-made post text** - publish as-is, with light polish only if requested.
- **Image file path** - optional local image to attach.

## Crafting the Post

When given an article or raw content:

- Keep the post under Threads' visible composer limit; target about 500 characters unless the UI allows more.
- Put the hook in the first line.
- End with a CTA or question when it fits naturally.
- Use 1-3 hashtags max at the end; avoid hashtag spam.
- Match the user's tone if they provide examples.

Show the draft to the user and wait for approval before publishing.

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

Click the composer control and wait for the editor/dialog to appear.

### Step 3: Fill content

- Paste the approved post text into the text editor.
- For an image post, use the attachment/upload control and set the supplied local file path.
- Wait for uploads and previews to finish before publishing.

Before publishing, verify the visible composer text and attached media match the approved draft.

### Step 4: Publish

Click the final publish button, commonly labeled `Post`, `Publish`, or `Thread`.

Wait until the composer closes and the new post appears, or until Threads shows a confirmation/error state.

### Step 5: Confirm and report

Tell the user:

- Success or failure.
- The visible post text that was published.
- The live post URL if Playwright can read it from the page or browser address.
- Any visible Threads error message on failure.

Never expose browser cookies, session storage, or other authentication data.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| Login required | Browser session is not authenticated | Ask the user to log in through the Playwright browser |
| Composer not found | Threads UI changed or page did not load | Refresh once, inspect the accessibility snapshot, then report the blocker |
| Upload fails | File path invalid, unsupported media, or upload issue | Ask for a valid local image path or retry once after the preview clears |
| Publish button disabled | Empty text, upload still processing, or validation issue | Wait for upload completion and check visible validation text |
| Rate/limit message | Threads account limit or platform restriction | Report the exact visible message and stop |
| Captcha/checkpoint | Threads security challenge | Ask the user to complete it manually in the browser |

## Important Notes

- This skill uses the Threads web UI, not `graph.threads.net`.
- Do not use curl, API containers, Meta app credentials, or long-lived tokens.
- Prefer visible UI labels and Playwright accessibility locators over brittle CSS selectors.
- Keep the browser profile persistent when possible so the user does not need to log in every run.
