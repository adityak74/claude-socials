---
name: threads-post-carousel
description: Publishes a carousel post to Meta Threads — a single post containing multiple images or videos. Trigger when the user says "carousel on Threads", "post multiple images to Threads", "Threads carousel", "share a gallery on Threads", or any intent to publish a multi-image or multi-video Threads post. Do NOT trigger for a single image post or reply chain threads — those have dedicated skills.
---

# Threads Post - Carousel

Publishes a multi-media Threads post through the web UI using Playwright MCP. This avoids Meta Graph API setup, app review, scoped access tokens, numeric user IDs, and container-publish flows.

## Prerequisites

- Playwright MCP is configured and available to the agent.
- The browser profile used by Playwright is logged in to Threads at `https://www.threads.net/`.
- Media files exist as local file paths the browser can access.

If the browser is not logged in, open Threads with Playwright and ask the user to complete login in the browser. Do not ask for a Meta access token.

## Optional Setup

Skills may use these environment variables when present:

- `THREADS_HANDLE` - the user's public Threads handle, used only for nicer reporting.
- `THREADS_PROFILE_DIR` - a persistent browser profile directory if the local Playwright MCP setup supports it.

Credentials are browser-session based. Do not create or request `THREADS_USER_ID` or `THREADS_ACCESS_TOKEN`.

## Inputs

- **Caption text** - optional but recommended.
- **Image/video file paths** - multiple local files to attach.

Ask the user for local media paths before proceeding. Browser automation cannot upload remote URLs directly unless the files are first downloaded to a local path.

## Crafting the Caption

When the user provides an article or raw content to accompany the carousel:

- Keep the caption within the visible Threads composer limit; target about 500 characters unless the UI allows more.
- Put the hook in the first line.
- Let the images carry the visual story.
- Use 1-3 hashtags max at the end.
- Match the user's tone if examples are provided.

Show the caption draft and media list to the user and wait for approval before publishing.

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

Open the composer and paste the approved caption.

### Step 3: Attach media

Use the attachment/upload control to set the approved local file paths. After attaching:

- Wait for every preview to render.
- Confirm the number and order of media items are correct.
- Watch for unsupported-format or upload-failed messages.

### Step 4: Publish

Click the final publish button, commonly labeled `Post`, `Publish`, or `Thread`.

Wait until the composer closes and the new post appears, or until Threads shows a confirmation/error state.

### Step 5: Confirm and report

Tell the user:

- Success or failure.
- The caption that was published.
- Number of media items attached.
- The live post URL if Playwright can read it from the page or browser address.
- Any visible Threads error message on failure.

Never expose browser cookies, session storage, or other authentication data.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| Login required | Browser session is not authenticated | Ask the user to log in through the Playwright browser |
| Upload control not found | Threads UI changed or composer did not load | Refresh once, inspect the accessibility snapshot, then report the blocker |
| Upload fails | File path invalid, unsupported media, too many files, or upload issue | Ask for valid local file paths or reduce the media set |
| Publish button disabled | Upload still processing or validation issue | Wait for previews and check visible validation text |
| Rate/limit message | Threads account limit or platform restriction | Report the exact visible message and stop |
| Captcha/checkpoint | Threads security challenge | Ask the user to complete it manually in the browser |

## Important Notes

- This skill uses the Threads web UI, not `graph.threads.net`.
- Do not use curl, API containers, Meta app credentials, or long-lived tokens.
- Threads UI limits may differ by account and platform rollout. Follow the visible UI limit and report any validation text.
- Prefer visible UI labels and Playwright accessibility locators over brittle CSS selectors.
- Keep the browser profile persistent when possible so the user does not need to log in every run.
