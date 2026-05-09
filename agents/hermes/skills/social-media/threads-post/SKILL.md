---
name: threads-post
description: Crafts and publishes a single text or image post to Meta Threads via the Graph API
version: 1.0.0
author: Aditya Karnam
license: MIT
platforms: [macos, linux, windows]

metadata:
  hermes:
    tags: [Social Media, Threads, Meta, Graph API, Publishing]
    related_skills: [threads-post-carousel, threads-post-thread, threads-post-spoiler]
    requires_toolsets: [web]
    requires_tools: [web_search]

required_environment_variables:
  - name: THREADS_USER_ID
    prompt: "Enter your numeric Threads user ID"
    help: "Get it via: curl 'https://graph.threads.net/v1.0/me?access_token=YOUR_TOKEN'"
    required_for: "Identifying your Threads account in API calls"
  - name: THREADS_ACCESS_TOKEN
    prompt: "Enter your long-lived Threads access token"
    help: "Generate at developers.facebook.com — needs threads_basic and threads_content_publish scopes"
    required_for: "Authenticating Graph API requests"
---

# Threads Post — Single Post

Publishes one text or image post to Meta Threads via the Meta Graph API (`graph.threads.net`) using the standard two-step container model.

## When to Use

Trigger when the user says "post to Threads", "share on Threads", "publish this to Threads", or similar intent for a **single** piece of content. Use `threads-post-carousel` for multi-image posts and `threads-post-thread` for reply chains.

## Quick Reference

- Base URL: `graph.threads.net/v1.0`
- Two-step: create container → wait 30s → publish
- Media types: `TEXT`, `IMAGE`
- Credentials file: `.socials`

## Procedure

### 1. Read credentials

```bash
echo $THREADS_USER_ID
echo $THREADS_ACCESS_TOKEN
```

If blank, check `.socials`:
```bash
grep -E "^THREADS_(USER_ID|ACCESS_TOKEN)=" .socials 2>/dev/null
```

If still missing, ask the user or run `hermes setup threads-post`.

### 2. Craft the post

When given article or raw content:
- Max ~500 characters
- Hook in the first line; end with a CTA or question
- 1–3 hashtags at the end — no spam
- Match the user's tone if examples provided

**Show the draft to the user and wait for approval before publishing.**

### 3. Create container

Text post:
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=TEXT" \
  --data-urlencode "text=YOUR_POST_TEXT" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Image post (image must be at a public URL):
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=IMAGE" \
  -d "image_url=https://example.com/image.jpg" \
  --data-urlencode "text=YOUR_CAPTION" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse the `id` — this is the `container_id`.

### 4. Wait and publish

```bash
sleep 30

curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` — this is the live post ID.

### 5. Report

Tell the user: success/failure, live post URL (`https://www.threads.net/@{handle}/post/{POST_ID}`), and raw API response on failure. Never expose the access token in output.

## Pitfalls

- The 30-second wait is required even for text-only posts — publishing too fast returns `400 / not ready`.
- Base URL is `graph.threads.net`, not `graph.facebook.com`.
- `THREADS_USER_ID` is a numeric ID, not the @handle.
- Long-lived tokens expire after 60 days — remind the user to refresh proactively.
- 250 posts per 24-hour rolling window per profile.

## Verification

On success, `threads_publish` returns a JSON object with `id`. Confirm the live URL is accessible before reporting success.
