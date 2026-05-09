---
name: threads-post-spoiler
description: Creates and publishes a spoiler post to Meta Threads — content that is hidden until the viewer taps to reveal it. Trigger when the user says "spoiler post on Threads", "hide this behind a spoiler", "tap to reveal post", "Threads spoiler", or any similar intent to post content that requires a tap to show. Supports text spoilers, media spoilers (image/video), and carousel spoilers. Do NOT trigger for regular posts or carousels — those have dedicated skills.
---

# Threads Post — Spoiler

Creates a spoiler post on Meta Threads — content hidden behind a tap-to-reveal overlay. Supports three spoiler types:

- **Text spoiler** — hide part or all of the post text using `text_entities`
- **Media spoiler** — hide the image or video with `is_spoiler_media=true`
- **Combined** — hide both text and media in one post

Spoilers work on text posts, image posts, video posts, and carousels. Uses the standard two-step container model of the Meta Graph API (`graph.threads.net`).

## Prerequisites

A Meta app with Threads enabled and a valid long-lived access token with `threads_basic` and `threads_content_publish` scopes.

## Credentials Setup

Load from environment variables:

- `THREADS_USER_ID` — numeric Threads user ID (not the @handle)
- `THREADS_ACCESS_TOKEN` — long-lived access token

**Setup:**
1. Create `.socials` in the project root (add to `.gitignore`):
   ```
   THREADS_USER_ID=123456789
   THREADS_ACCESS_TOKEN=EAAxxxxxxxxxxxxx
   ```
2. Or export in shell: `export THREADS_USER_ID=... THREADS_ACCESS_TOKEN=...`

**How to get credentials:**
1. Create a Meta app at [developers.facebook.com](https://developers.facebook.com) and add the Threads product
2. Generate a User Token with scopes: `threads_basic`, `threads_content_publish`
3. Exchange for a long-lived token (60-day expiry)
4. Get your numeric user ID: `GET https://graph.threads.net/v1.0/me?access_token=TOKEN`

Do NOT hardcode credentials. If env vars are missing, ask the user to set them.

## Inputs

Ask the user:
1. **Post content** — the text (and/or image/video URL) to hide
2. **Spoiler type** — text spoiler, media spoiler, or both?
3. For text spoilers: **which part of the text** should be hidden? (offset + length, or the whole thing)

## Spoiler Parameters

### Text spoilers — `text_entities`

Pass a JSON array. Each entry hides a range of characters in the post text:

```
text_entities=[{"entity_type":"SPOILER","offset":0,"length":20}]
```

- `offset` — 0-based character position where the spoiler starts
- `length` — number of characters to hide from that offset
- Max 10 spoiler entities per post
- To hide the entire text: `offset=0`, `length=<total character count>`

### Media spoilers — `is_spoiler_media`

```
is_spoiler_media=true
```

- Works with `media_type=IMAGE`, `VIDEO`, or `CAROUSEL`
- On carousels, `is_spoiler_media=true` marks **all** attached media as spoilers

## Crafting the Post

When the user provides an article or content to hide:
- Write the spoiler text (the part to be hidden)
- Optionally write a teaser line before the spoiler to entice the reader
- Keep total text under ~500 characters
- 1–3 hashtags max at the end — no spam

**Show the draft and the spoiler range to the user for approval before publishing.**

## Workflow

### Step 1: Read credentials

```bash
echo $THREADS_USER_ID
echo $THREADS_ACCESS_TOKEN
```

If blank, check `.socials`:
```bash
grep -E "^THREADS_(USER_ID|ACCESS_TOKEN)=" .socials 2>/dev/null
```

If still missing, stop and ask the user to set them.

### Step 2: Create container

**Text spoiler only** (hide characters 0–49 of the post text):
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=TEXT" \
  --data-urlencode "text=YOUR_POST_TEXT" \
  --data-urlencode 'text_entities=[{"entity_type":"SPOILER","offset":0,"length":50}]' \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

**Image spoiler** (hide the entire image):
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=IMAGE" \
  -d "image_url=https://example.com/image.jpg" \
  --data-urlencode "text=YOUR_CAPTION" \
  -d "is_spoiler_media=true" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

**Combined** — hide both text and media:
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

**Carousel spoiler** (all media hidden):
```bash
# First create item containers (same as threads-post-carousel, with is_carousel_item=true)
# Then create the carousel container:
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=CAROUSEL" \
  -d "children=ITEM_ID_1,ITEM_ID_2" \
  --data-urlencode "text=YOUR_CAPTION" \
  -d "is_spoiler_media=true" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse the `id` field from the response — this is the `container_id`.

### Step 3: Wait and publish

```bash
sleep 30

curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` — this is the live post ID.

### Step 4: Confirm and report

Tell the user:
- Success or failure
- Live post URL: `https://www.threads.net/@{handle}/post/{POST_ID}`
- Which content was marked as a spoiler (text range, media, or both)
- Raw API response on failure for debugging

Never expose the access token in output.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| 401 | Token expired or revoked | Ask user to refresh long-lived token |
| 403 | Missing scope | User must reauthorize with `threads_basic` + `threads_content_publish` |
| 400 / not ready | Published too quickly | Wait 15 more seconds, retry publish once |
| 400 / invalid text_entities | Offset or length out of range | Recalculate — offset + length must not exceed total text length |
| 429 | 250 posts per 24h limit hit | Tell user to wait |
| Media fetch failure | URL not publicly accessible | Ask user to re-host the file |

## Important Notes

- Base URL is `graph.threads.net`, not `graph.facebook.com`.
- `THREADS_USER_ID` is the numeric ID, not the @handle.
- `text_entities` must be URL-encoded JSON — use `--data-urlencode` in curl.
- `offset` is 0-based. To hide the entire text: `offset=0`, `length=<len(text)>`.
- Maximum 10 `text_entities` entries per post.
- `is_spoiler_media=true` on a carousel hides all attached media, not individual items.
- The 30-second wait before publishing is required.
- Long-lived tokens expire after 60 days — remind the user to refresh proactively.
