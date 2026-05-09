---
name: threads-post-spoiler
description: Creates and publishes a spoiler post to Meta Threads — content hidden until the viewer taps to reveal it. Supports text spoilers, media spoilers, and combined spoilers.
version: 1.0.0
author: Aditya Karnam
license: MIT
platforms: [macos, linux, windows]

metadata:
  hermes:
    tags: [Social Media, Threads, Meta, Graph API, Spoiler, Hidden Content]
    related_skills: [threads-post, threads-post-carousel, threads-post-thread]
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

# Threads Post — Spoiler

Creates a spoiler post on Meta Threads — content hidden behind a tap-to-reveal overlay. Three spoiler types:

- **Text spoiler** — hide a range of characters using `text_entities`
- **Media spoiler** — hide image/video with `is_spoiler_media=true`
- **Combined** — hide both text and media

## When to Use

Trigger when the user says "spoiler post on Threads", "hide this behind a spoiler", "tap to reveal post", "Threads spoiler", or similar. Use `threads-post` for regular posts and `threads-post-carousel` for galleries.

## Quick Reference

- Text spoiler param: `text_entities=[{"entity_type":"SPOILER","offset":0,"length":N}]`
- Media spoiler param: `is_spoiler_media=true`
- Max 10 `text_entities` entries per post
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

### 2. Gather inputs

Ask the user:
1. **Post content** — the text (and/or image/video URL) to hide
2. **Spoiler type** — text, media, or both?
3. For text spoilers: which part to hide? (offset + length, or the full text)

### 3. Craft the post

- Write the spoiler text (the hidden part)
- Optionally write a visible teaser line before the spoiler
- Keep total text under ~500 characters; 1–3 hashtags max at the end

**Show the draft and spoiler range to the user for approval before publishing.**

### 4. Create container

**Text spoiler** (hide characters 0–49):
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=TEXT" \
  --data-urlencode "text=YOUR_POST_TEXT" \
  --data-urlencode 'text_entities=[{"entity_type":"SPOILER","offset":0,"length":50}]' \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

**Image spoiler:**
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=IMAGE" \
  -d "image_url=https://example.com/image.jpg" \
  --data-urlencode "text=YOUR_CAPTION" \
  -d "is_spoiler_media=true" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

**Combined:**
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=IMAGE" \
  -d "image_url=https://example.com/image.jpg" \
  --data-urlencode "text=YOUR_POST_TEXT" \
  --data-urlencode 'text_entities=[{"entity_type":"SPOILER","offset":0,"length":50}]' \
  -d "is_spoiler_media=true" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → `CONTAINER_ID`.

### 5. Wait and publish

```bash
sleep 30
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

### 6. Report

Tell the user: success/failure, live post URL, which content was hidden (text range, media, or both). Never expose the access token.

## Pitfalls

- `text_entities` must be URL-encoded JSON — always use `--data-urlencode`.
- `offset` is 0-based. `offset + length` must not exceed total text length — out-of-range causes `400`.
- `is_spoiler_media=true` on a carousel hides ALL attached media, not individual items.
- Maximum 10 `text_entities` entries per post.
- The 30-second wait before publishing is required.
- Long-lived tokens expire after 60 days.

## Verification

On success, `threads_publish` returns a JSON object with `id`. Open the live URL in a browser or app to confirm the spoiler overlay is visible before tapping.
