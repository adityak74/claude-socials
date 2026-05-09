---
name: threads-post-carousel
description: Publishes a carousel post (2–10 images or videos) to Meta Threads via the Graph API
version: 1.0.0
author: Aditya Karnam
license: MIT
platforms: [macos, linux, windows]

metadata:
  hermes:
    tags: [Social Media, Threads, Meta, Graph API, Carousel, Gallery]
    related_skills: [threads-post, threads-post-thread, threads-post-spoiler]
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

# Threads Post — Carousel

Publishes a carousel post to Meta Threads — a single post containing 2–10 images, videos, or a mix of both. Counts as one post against the 250-post-per-24h limit.

## When to Use

Trigger when the user says "carousel on Threads", "post multiple images to Threads", "Threads carousel", "share a gallery on Threads", or any multi-image/video Threads intent. Use `threads-post` for single images and `threads-post-thread` for reply chains.

## Quick Reference

- Three-step flow: item containers → carousel container → publish
- 2–10 media items per carousel
- All media must be at publicly accessible URLs (Meta fetches server-side)
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

If still missing, ask the user or run `hermes setup threads-post-carousel`.

### 2. Gather inputs

Ask the user for:
- **Caption** — text for the carousel post (optional but recommended)
- **Media URLs** — 2 to 10 publicly accessible image or video URLs

Confirm the list before proceeding. **Show the caption draft to the user for approval.**

### 3. Create item containers

For each image:
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=IMAGE" \
  -d "image_url=https://example.com/1.jpg" \
  -d "is_carousel_item=true" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

For each video:
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=VIDEO" \
  -d "video_url=https://example.com/clip.mp4" \
  -d "is_carousel_item=true" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Collect all `id` values: `ITEM_ID_1`, `ITEM_ID_2`, …

### 4. Create carousel container

```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=CAROUSEL" \
  -d "children=ITEM_ID_1,ITEM_ID_2,ITEM_ID_3" \
  --data-urlencode "text=YOUR_CAPTION" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → `CAROUSEL_CONTAINER_ID`.

### 5. Wait and publish

```bash
sleep 30

curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=CAROUSEL_CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

### 6. Report

Tell the user: success/failure, live post URL, number of media items published. Never expose the access token.

## Pitfalls

- Minimum 2 items, maximum 10 items per carousel.
- All media must be publicly reachable — private or authenticated URLs will fail silently.
- The 30-second wait is required before publishing.
- Base URL is `graph.threads.net`, not `graph.facebook.com`.
- Long-lived tokens expire after 60 days.

## Verification

On success, `threads_publish` returns a JSON object with `id`. Confirm the live URL renders the carousel correctly.
