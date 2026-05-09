---
name: threads-post-thread
description: Crafts and publishes a threaded reply chain to Meta Threads — a root post followed by a series of connected replies that form a thread. Trigger when the user says "create a thread on Threads", "thread this article", "post a thread", "make a multi-part thread", "thread chain", or any intent to publish a sequence of connected posts on Threads. Do NOT trigger for a single post or multi-image carousel — those have dedicated skills.
---

# Threads Post — Thread Chain

Publishes a root post followed by a chain of connected replies on Meta Threads. Each reply targets the previous post's ID, forming a linear thread (1 → 2 → 3 → …). Uses the Meta Graph API (`graph.threads.net`).

**Rate limits:**
- 250 root posts per rolling 24-hour window per profile
- 1,000 API-published replies per rolling 24-hour window per profile

## Prerequisites

A Meta app with Threads enabled and a valid long-lived access token with:
- `threads_basic`
- `threads_content_publish`
- `threads_manage_replies` ← required for posting replies

## Credentials Setup

Load from environment variables:

- `THREADS_USER_ID` — numeric Threads user ID (not the @handle)
- `THREADS_ACCESS_TOKEN` — long-lived access token with all three scopes above

**Setup:**
1. Create `.socials` in the project root (add to `.gitignore`):
   ```
   THREADS_USER_ID=123456789
   THREADS_ACCESS_TOKEN=EAAxxxxxxxxxxxxx
   ```
2. Or export in shell: `export THREADS_USER_ID=... THREADS_ACCESS_TOKEN=...`

**How to get credentials:**
1. Create a Meta app at [developers.facebook.com](https://developers.facebook.com) and add the Threads product
2. Generate a User Token with scopes: `threads_basic`, `threads_content_publish`, `threads_manage_replies`
3. Exchange for a long-lived token (60-day expiry)
4. Get your numeric user ID: `GET https://graph.threads.net/v1.0/me?access_token=TOKEN`

Do NOT hardcode credentials. If env vars are missing, ask the user to set them.

## Inputs

- **Article or long-form content** — you will break it into a thread
- **Ready-made posts** — a list of posts to publish in order

Ask if it is unclear how many posts should be in the chain (default: 3–8).

## Crafting the Thread

When given an article or raw content:
- Break into **3–8 logical chunks**, each under **500 characters**
- Post 1 (root): the hook — strong opening that makes people want to read on
- Posts 2 … N-1: the body — one clear point per post, flowing naturally into the next
- Last post: CTA or closing takeaway
- Number them: `1/5`, `2/5`, …
- 1–3 hashtags at the end of the **last post only** — no spam
- Each post should stand alone but reward reading in sequence
- Match the user's tone if examples are provided

**Show the full thread draft to the user and wait for approval before publishing.**

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

### Step 2: Publish the root post

**2a. Create container:**
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=TEXT" \
  --data-urlencode "text=ROOT_POST_TEXT" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → `ROOT_CONTAINER_ID`.

**2b. Wait and publish:**
```bash
sleep 30

curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=ROOT_CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → save as `REPLY_TO_ID`. This is the root post's live ID.

### Step 3: For each subsequent post in the chain

Repeat for posts 2, 3, … N.

**3a. Create reply container** (use `/me/threads` for replies):
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/me/threads" \
  -d "media_type=TEXT" \
  --data-urlencode "text=NEXT_POST_TEXT" \
  -d "reply_to_id=${REPLY_TO_ID}" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → `REPLY_CONTAINER_ID`.

**3b. Wait and publish:**
```bash
sleep 30

curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=REPLY_CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → update `REPLY_TO_ID` to this new live post ID before the next iteration.

**3c. Repeat** until all posts are published.

### Step 4: Confirm and report

Tell the user:
- Success or failure for each post in the chain
- Live URL for the root post: `https://www.threads.net/@{handle}/post/{ROOT_POST_ID}`
- Total posts published
- Raw API response for any failed post for debugging

Never expose the access token in output.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| 401 | Token expired or revoked | Ask user to refresh long-lived token |
| 403 | Missing scope | User must reauthorize — ensure `threads_manage_replies` is included |
| 400 / not ready | Published too quickly | Wait 15 more seconds, retry publish once |
| 429 on root post | 250-post limit hit | Tell user to wait |
| 429 on reply | 1,000-reply limit hit | Tell user to wait |
| Media fetch failure | URL not publicly accessible | Ask user to re-host the file |

## Important Notes

- Base URL is `graph.threads.net`, not `graph.facebook.com`.
- `THREADS_USER_ID` is the numeric ID, not the @handle.
- Root post containers use `/{THREADS_USER_ID}/threads`; reply containers use `/me/threads`.
- Publishing always uses `/{THREADS_USER_ID}/threads_publish` regardless of post type.
- Each post in the chain requires its own 30-second wait before publishing.
- The chain is linear: each reply targets the immediately preceding post's live ID, not the root post. This creates a 1→2→3 chain rather than a 1←2, 1←3 fan.
- Long-lived tokens expire after 60 days — remind the user to refresh proactively.
