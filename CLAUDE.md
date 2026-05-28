# youtube-video-processor

A Node.js worker that polls a Supabase Postgres database for jobs, downloads timestamped clips from YouTube, concatenates them with ffmpeg, and uploads the result to Supabase Storage.

## Architecture

**Poll loop** — `src/index.js` runs an infinite loop that claims one job at a time, processes it, then immediately polls again. If no job is found it sleeps `POLL_INTERVAL_MS` (10 s) before retrying.

**Job claim** — `src/jobs.js` uses `SELECT ... FOR UPDATE SKIP LOCKED` to safely claim a single `queued` row and flip it to `processing`. This makes multiple worker instances safe to run in parallel without double-processing.

**Download** — `src/downloader.js` calls `yt-dlp` via `execFile`. It uses `--download-sections` with `--force-keyframes-at-cuts` to fetch only the requested time range from YouTube, writing the result to a temp file.

**Concat** — `src/ffmpeg.js` writes an ffmpeg concat list file and runs `ffmpeg -f concat -c copy` to stitch clips losslessly. No re-encoding happens — clips must be compatible (same codec/resolution) for this to work correctly.

**Upload** — `src/storage.js` reads the output file and uploads it to the `exports` Supabase Storage bucket, returning the public URL.

**Cleanup** — each job gets a dedicated `/tmp/job_<id>/` working directory that is removed in a `finally` block whether the job succeeds or fails.

## Database Schema

The worker expects a `jobs` table with at least these columns:

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid / serial | primary key |
| `status` | text | `queued` → `processing` → `done` / `failed` |
| `clips` | jsonb | array of `{ url, start, end }` objects |
| `output_path` | text | written on success (public storage URL) |
| `error` | text | written on failure |
| `created_at` | timestamptz | used for FIFO ordering |
| `updated_at` | timestamptz | updated on every status change |

Clips format example:
```json
[
  { "url": "https://www.youtube.com/watch?v=XXXX", "start": "00:01:10", "end": "00:01:45" },
  { "url": "https://www.youtube.com/watch?v=XXXX", "start": "00:03:00", "end": "00:03:30" }
]
```

`start`/`end` are passed directly to yt-dlp's `--download-sections` flag (accepts `HH:MM:SS` or seconds).

## Environment Variables

Defined in `.env.example`:

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | Postgres connection string (Supabase direct connection) |
| `SUPABASE_URL` | Supabase project URL (for Storage API) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key — bypasses RLS, keep secret |

## Runtime Dependencies

- **Node.js 20** — ESM (`"type": "module"`)
- **yt-dlp** — must be on `PATH`; handles YouTube download with time-range slicing
- **ffmpeg 6.1** — must be on `PATH`; handles lossless clip concatenation
- **`@supabase/supabase-js`** — Storage upload
- **`postgres`** — direct Postgres client for job queue operations (not the Supabase JS client)

## Docker

The `Dockerfile` starts from `jrottenberg/ffmpeg:6.1-ubuntu`, installs Node 20 and yt-dlp via pip, then copies the app. Build and run:

```sh
docker build -t yt-processor .
docker run --env-file .env yt-processor
```

## Key Design Decisions

- **Polling over realtime**: the worker polls rather than using Supabase Realtime. Simple and stateless — any number of replicas can run against the same DB without coordination.
- **`FOR UPDATE SKIP LOCKED`**: the correct pattern for Postgres-backed job queues with concurrent workers. Do not replace with application-level locking.
- **`execFile` not `exec`**: arguments are passed as an array, avoiding shell injection from untrusted URLs or timestamps.
- **`-c copy` in ffmpeg**: lossless concat — fast but requires all clips to share the same codec and resolution. If clips ever differ (e.g. mixed 720p/1080p), re-encoding will be needed.
- **`upsert: true` on upload**: re-running a failed job overwrites the previous partial upload rather than erroring.
