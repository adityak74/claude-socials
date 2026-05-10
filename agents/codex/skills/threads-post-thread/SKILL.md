---
name: threads-post-thread
description: Crafts and publishes a threaded reply chain to Meta Threads — a root post followed by a series of connected replies that form a thread. Trigger when the user says "create a thread on Threads", "thread this article", "post a thread", "make a multi-part thread", "thread chain", or any intent to publish a sequence of connected posts on Threads. Do NOT trigger for a single post or multi-image carousel — those have dedicated skills.
---

# Threads Post - Thread Chain

Publishes a root post followed by connected replies on Meta Threads through the web UI using Playwright MCP. This avoids Meta Graph API setup, app review, scoped access tokens, numeric user IDs, and container-publish flows.

## Prerequisites

- Playwright MCP is configured and available to the agent.
- The browser profile used by Playwright is logged in to Threads at `https://www.threads.net/`.

If the browser is not logged in, open Threads with Playwright and ask the user to complete login in the browser. Do not ask for a Meta access token.

## Optional Setup

Skills may use these environment variables when present:

- `THREADS_HANDLE` - the user's public Threads handle, used only for nicer reporting.
- `THREADS_PROFILE_DIR` - a persistent browser profile directory if the local Playwright MCP setup supports it.

Credentials are browser-session based. Do not create or request `THREADS_USER_ID` or `THREADS_ACCESS_TOKEN`.

## Inputs

- **Article or long-form content** - break it into a thread.
- **Ready-made posts** - publish each post in order.

Ask if it is unclear how many posts should be in the chain. Default to 3-8 posts.

## Crafting the Thread

When given an article or raw content:

- Break it into 3-8 logical chunks.
- Keep each post within the visible Threads composer limit; target about 500 characters unless the UI allows more.
- Post 1 is the hook.
- Middle posts carry one clear point each.
- The last post closes with a takeaway, CTA, or question.
- Number them as `1/N`, `2/N`, etc. unless the user asks for an unnumbered style.
- Put hashtags only on the last post, 1-3 max.
- Match the user's tone if examples are provided.

Show the full thread draft to the user and wait for approval before publishing.

## Workflow

### Step 1: Open Threads

Use Playwright MCP to navigate to:

```text
https://www.threads.net/
```

If the login screen appears, stop and ask the user to log in through the browser. After login, continue with the same browser session.

### Step 2: Create the root post

Use Playwright's accessibility snapshot or locator tools to find the composer entry point. Common labels include:

- `New thread`
- `Start a thread`
- `Post`
- `Create`

Open the composer, paste the approved root post, verify the visible text, and publish it.

### Step 3: Open the published root post

After publishing, open the new root post from the feed, profile, or visible success state. Capture its URL if available.

If the root post cannot be found reliably, stop and report the blocker instead of guessing where replies will attach.

### Step 4: Reply in order

For each remaining post:

- Open the reply composer for the current post.
- Paste the next approved post.
- Verify the visible text.
- Publish the reply.
- Wait until the reply is visible.
- Continue from the newly published reply when the UI supports a linear chain. If the UI only exposes replying to the root, state that limitation before continuing.

### Step 5: Confirm and report

Tell the user:

- Success or failure for each post.
- The root post URL if Playwright can read it.
- Total posts published.
- Any visible Threads error message on failure.

Never expose browser cookies, session storage, or other authentication data.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| Login required | Browser session is not authenticated | Ask the user to log in through the Playwright browser |
| Composer/reply button not found | Threads UI changed or page did not load | Refresh once, inspect the accessibility snapshot, then report the blocker |
| Root post not found | Feed did not show the new post or navigation failed | Stop and ask the user whether to continue manually |
| Publish button disabled | Empty text or visible validation issue | Check the composer text and report the validation message |
| Rate/limit message | Threads account limit or platform restriction | Report the exact visible message and stop |
| Captcha/checkpoint | Threads security challenge | Ask the user to complete it manually in the browser |

## Important Notes

- This skill uses the Threads web UI, not `graph.threads.net`.
- Do not use curl, API containers, Meta app credentials, or long-lived tokens.
- Prefer visible UI labels and Playwright accessibility locators over brittle CSS selectors.
- Keep the browser profile persistent when possible so the user does not need to log in every run.
