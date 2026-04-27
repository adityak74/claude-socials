---
description: Publishes a carousel post to Meta Threads — a single post containing up to 10 images or videos. Trigger when the user says "carousel on Threads", "post multiple images to Threads", "Threads carousel", "share a gallery on Threads", or any intent to publish a multi-image or multi-video Threads post. For a single image post use threads-post. For a reply chain use threads-post-thread.
---

# Threads Post — Carousel

Publishes a carousel post to Meta Threads via the Meta Graph API. A carousel is a single Threads post that contains 2–10 images, videos, or a mix of both. It counts as one post against the 250-post-per-24h publishing limit.

## Prerequisites

A Meta app with Threads enabled, and a valid long-lived access token with `threads_basic` and `threads_content_publish` scopes.

## Credentials Setup

Load from environment variables:

- `THREADS_USER_ID` — numeric Threads user ID (not the @handle)
- `THREADS_ACCESS_TOKEN` — long-lived access token

**Setup:**
1. Create `.env` in the project root (add to `.gitignore`):
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

- **Caption text** — the text shown on the carousel post (optional but recommended)
- **Image / video URLs** — 2 to 10 publicly accessible URLs (images or videos)

Ask the user for the media URLs before proceeding. All URLs must be publicly reachable — Meta fetches them server-side.

## Crafting the Caption

When the user provides an article or raw content to accompany the carousel:
- Max ~500 characters
- Hook in the first line; the images carry the visual story
- 1–3 hashtags at the end — no spam
- Match the user's tone if examples are provided

**Show the caption draft to the user and confirm the image list before publishing.**

## Workflow

This is a three-step flow: create item containers → create carousel container → publish.

### Step 1: Read credentials

```bash
echo $THREADS_USER_ID
echo $THREADS_ACCESS_TOKEN
```

If blank, check `.env`:
```bash
grep -E "^THREADS_(USER_ID|ACCESS_TOKEN)=" .env 2>/dev/null
```

If still missing, stop and ask the user to set them.

### Step 2: Create one container per media item

For each image URL:
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=IMAGE" \
  -d "image_url=https://example.com/1.jpg" \
  -d "is_carousel_item=true" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

For a video item, use `media_type=VIDEO` and `video_url=https://...` instead:
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=VIDEO" \
  -d "video_url=https://example.com/clip.mp4" \
  -d "is_carousel_item=true" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Collect the `id` from each response. You'll have `ITEM_ID_1`, `ITEM_ID_2`, … up to `ITEM_ID_10`.

### Step 3: Create the carousel container

```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=CAROUSEL" \
  -d "children=ITEM_ID_1,ITEM_ID_2,ITEM_ID_3" \
  --data-urlencode "text=YOUR_CAPTION" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` from the response — this is `CAROUSEL_CONTAINER_ID`.

### Step 4: Wait and publish

```bash
sleep 30

curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=CAROUSEL_CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` — this is the live post ID.

### Step 5: Confirm and report

Tell the user:
- Success or failure
- Live post URL: `https://www.threads.net/@{handle}/post/{POST_ID}`
- Number of media items published
- Raw API response on failure for debugging

Never expose the access token in output.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| 401 | Token expired or revoked | Ask user to refresh long-lived token |
| 403 | Missing scope | User must reauthorize with `threads_basic` + `threads_content_publish` |
| 400 / not ready | Published too quickly | Wait 15 more seconds, retry publish once |
| 429 | 250 posts per 24h limit hit | Tell user to wait |
| Media fetch failure | URL not publicly accessible | Ask user to re-host the file |
| > 10 items | Carousel limit exceeded | Ask user to reduce to 10 items max |

## Important Notes

- Base URL is `graph.threads.net`, not `graph.facebook.com`.
- `THREADS_USER_ID` is the numeric ID, not the @handle.
- Carousel minimum is 2 items; maximum is 10.
- All media must be at publicly reachable URLs — Meta fetches server-side.
- The 30-second wait before the final publish step is required.
- Long-lived tokens expire after 60 days — remind the user to refresh proactively.
