# youtube-video-processor

A Node.js worker that polls a Supabase Postgres database for jobs, downloads timestamped clips from YouTube, concatenates them with ffmpeg, and uploads the result to Supabase Storage.

## Architecture

**Poll loop** — `src/index.js` runs an infinite loop that claims one job at a time, processes it, then immediately polls again. If no job is found it sleeps `POLL_INTERVAL_MS` (10 s) before retrying.

**Job claim** — `src/jobs.js` calls `supabase.rpc('claim_job', { p_runner })`, a Postgres stored procedure that uses `SELECT ... FOR UPDATE SKIP LOCKED` internally. This makes multiple worker instances safe to run in parallel without double-processing. `p_runner` (defaulting to `null`) optionally restricts which `runner` value a given worker instance claims — see `WORKER_RUNNER` below.

**Supabase client** — `src/supabase.js` exports a single shared `supabase` client instance (service role) used by both `jobs.js` and `storage.js`.

**Download** — `src/downloader.js` calls `yt-dlp` via `execFile`. It uses `--download-sections` with `--force-keyframes-at-cuts` to fetch only the requested time range from YouTube, writing the result to a temp file.

**Concat** — `src/ffmpeg.js` writes an ffmpeg concat list file and runs `ffmpeg -f concat -c copy` to stitch clips losslessly. No re-encoding happens — clips must be compatible (same codec/resolution) for this to work correctly.

**Upload** — `src/storage.js` reads the output file and uploads it to the `exports` Supabase Storage bucket, returning the public URL.

**Cleanup** — each job gets a dedicated `/tmp/job_<id>/` working directory that is removed in a `finally` block whether the job succeeds or fails.

## Data Model

The app is a padel match analysis platform. Jobs are created when a user selects events from a session to export as a video clip:

- `sessions` — a match; has a `youtube_url`
- `events` — timestamped moments in the match (`timestamp_seconds_start`, `timestamp_seconds_end`)
- `youtube_jobs` — a user-initiated export; references the session and the selected events

## Database Schema

The worker reads from the `youtube_jobs` table:

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | primary key |
| `session_id` | uuid | FK to `sessions` |
| `type` | text | `clip_export` (extensible via CHECK constraint) |
| `status` | text | `queued` → `processing` → `done` / `failed` |
| `clips` | jsonb | array of `{ start, end }` — resolved at job creation |
| `event_ids` | uuid[] | source event IDs the user selected (UI reference only) |
| `output_path` | text | written on success (public storage URL) |
| `error` | text | written on failure |
| `created_at` | timestamptz | used for FIFO ordering |
| `updated_at` | timestamptz | updated by DB trigger on every status change |
| `video_status` | text | `available` or `expired` — tracks whether the YouTube video is still accessible |
| `youtube_url` | text | YouTube URL for all clips in this job |
| `runner` | text | `cloud` (default) or `local` — controls output destination (see below) |

Clips format — `start`/`end` are seconds (matching `events.timestamp_seconds_start/end`). The YouTube URL is stored once on the job row in `youtube_url`, not per-clip:
```json
[
  { "start": 70.5, "end": 85.0 },
  { "start": 180.0, "end": 210.0 }
]
```

The `claim_job()` stored procedure (defined in `claim_job.sql` — `schema.sql` is an auto-generated, tables-only dump that doesn't capture functions) is how the worker atomically claims a queued row, optionally filtered to one `runner` value via its `p_runner` argument.

**Runner modes** — `runner` (a per-job property, set at job creation) determines where the output file is delivered after concat:

- `cloud`: uploaded to Supabase Storage (`exports` bucket); `output_path` is set to the public URL
- `local`: copied to `LOCAL_OUTPUT_DIR` on the machine running the worker (defaults to `~/Downloads`); `output_path` is set to the local file path

This is distinct from `WORKER_RUNNER` (a per-worker-instance env var) which determines what a given worker instance is allowed to *claim* in the first place.

> **Docker constraint**: when running inside a container, only `cloud` jobs make sense — the container has no access to the host filesystem, so `local` jobs would write to a path inside the container that disappears on exit. This is enforced at the database level: a Docker-deployed worker defaults to `WORKER_RUNNER=cloud`, which is passed to `claim_job()` as `p_runner`, so it physically cannot claim `local` jobs.

## Environment Variables

Defined in `.env.example`:

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key — bypasses RLS, keep secret |
| `LOCAL_OUTPUT_DIR` | Directory for `runner=local` jobs (default: `~/Downloads`) |
| `WORKER_RUNNER` | Which `runner` value this worker instance claims (`cloud` or `local`, default `cloud`); validated at startup |

## Runtime Dependencies

- **Node.js 20** — ESM (`"type": "module"`); start with `npm start` (uses `--env-file=.env`)
- **yt-dlp** — must be on `PATH`; handles YouTube download with time-range slicing
- **ffmpeg 6.1** — must be on `PATH`; handles lossless clip concatenation
- **`@supabase/supabase-js`** — all Supabase interactions (job queue via RPC + Storage upload)
- **`ws`** — WebSocket transport passed to the Supabase client; required for the Realtime connection to work in Node.js

## Docker

The `Dockerfile` starts from `jrottenberg/ffmpeg:6.1-ubuntu`, installs Node 20 and yt-dlp via pip, then copies the app. Build and run:

```sh
docker build -t yt-processor .
docker run --env-file .env yt-processor
```

## Key Design Decisions

- **Polling over realtime**: the worker polls rather than using Supabase Realtime. Simple and stateless — any number of replicas can run against the same DB without coordination.
- **`claim_job()` stored procedure**: keeps `FOR UPDATE SKIP LOCKED` logic in the database, avoids needing a direct Postgres connection string, and works correctly with concurrent workers.
- **`execFile` not `exec`**: arguments are passed as an array, avoiding shell injection from untrusted URLs or timestamps.
- **`-c copy` in ffmpeg**: lossless concat — fast but requires all clips to share the same codec and resolution. If clips ever differ (e.g. mixed 720p/1080p), re-encoding will be needed.
- **`upsert: true` on upload**: re-running a failed job overwrites the previous partial upload rather than erroring.
- **Clips resolved at job creation**: the worker is kept dumb — it processes whatever is in `clips` without needing to query `sessions` or `events`. The caller (API/frontend) is responsible for building the clips array from the selected events.

## Current Operation

Two worker instances run in practice, distinguished by `WORKER_RUNNER`:

- **VPS (perpetual)** — runs as an always-on Docker container (`docker-compose.yml`, `restart: unless-stopped`) with `WORKER_RUNNER=cloud` (the default). It only ever claims and processes `runner = 'cloud'` jobs. See README's "Deploying to a VPS" section for operational commands.
- **Local (manual, on demand)** — `runner = 'local'` jobs are left untouched in the queue by the VPS worker; process them by running `WORKER_RUNNER=local npm start` on your own machine, which delivers output to `LOCAL_OUTPUT_DIR`.

The worker is already stateless and supports concurrent replicas (via `claim_job()`'s `FOR UPDATE SKIP LOCKED`), so horizontal scaling requires no additional changes.
