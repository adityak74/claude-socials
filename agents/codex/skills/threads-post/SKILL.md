---
name: threads-post
description: Crafts and publishes a single text or image post to Meta Threads using the Graph API. Trigger when the user says "post to Threads", "share on Threads", "publish this to Threads", "put this on Threads", or any similar intent to post a single piece of content to Threads. Do NOT trigger for carousel (multi-image) posts or reply chain threads — those have dedicated skills.
---

# Threads Post — Single Post

Publishes one text or image post to Meta Threads via the Meta Graph API (`graph.threads.net`) using the standard two-step container model.

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

- **Article or content** — you will craft a concise Threads post from it
- **Ready-made post text** — publish as-is (light polish if asked)
- **Image URL** — publicly accessible URL for an image post (optional)

## Crafting the Post

When given an article or raw content:
- Max ~500 characters
- Hook in the first line
- End with a CTA or question
- 1–3 hashtags max at the end — no hashtag spam
- Match the user's tone if they've provided examples

**Show the draft to the user and wait for approval before publishing.**

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

Parse the `id` field from the response — this is the `container_id`.

### Step 3: Wait and publish

```bash
sleep 30

curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` from the response — this is the live post ID.

### Step 4: Confirm and report

Tell the user:
- Success or failure
- Live post URL: `https://www.threads.net/@{handle}/post/{POST_ID}`
- Raw API response on failure for debugging

Never expose the access token in output.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| 401 | Token expired or revoked | Ask user to refresh long-lived token |
| 403 | Missing scope | User must reauthorize with `threads_basic` + `threads_content_publish` |
| 400 / not ready | Published too quickly | Wait 15 more seconds, retry publish once |
| 429 | 250 posts per 24h limit hit | Tell user to wait |
| Image fetch failure | URL not publicly accessible | Ask user to re-host the image |

## Important Notes

- Base URL is `graph.threads.net`, not `graph.facebook.com`.
- `THREADS_USER_ID` is the numeric ID, not the @handle.
- The 30-second wait before publishing is required even for text-only posts.
- Long-lived tokens expire after 60 days — remind the user to refresh proactively.
