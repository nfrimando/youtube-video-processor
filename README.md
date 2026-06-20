# youtube-video-processor

## Prerequisites

- Node.js 20
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) on `PATH`
- [ffmpeg 6.1](https://ffmpeg.org/) on `PATH`

## Running locally

1. Copy `.env.example` to `.env` and fill in your Supabase credentials.
2. Install dependencies:
   ```sh
   npm install
   ```
3. Start the worker:
   ```sh
   npm start
   ```

The worker polls for queued jobs, processes them, and keeps running until stopped (`Ctrl+C`).

## Job runner modes

Each job has a `runner` column (`cloud` | `local`, default `cloud`) that controls where the output file is delivered:

| `runner` | Output destination |
|----------|--------------------|
| `cloud` | Uploaded to Supabase Storage (`exports` bucket); `output_path` is set to the public URL |
| `local` | Copied to `LOCAL_OUTPUT_DIR` on the machine running the worker (defaults to `~/Downloads`); `output_path` is set to the local file path |

Set `LOCAL_OUTPUT_DIR` in `.env` to override the local output directory.

A worker instance only ever *claims* jobs matching its own `WORKER_RUNNER` env var (`cloud` or `local`, default `cloud`) — set via `claim_job(p_runner)`. This is separate from a job's own `runner` column: `WORKER_RUNNER` decides what a given worker is allowed to pick up, while `runner` (set at job creation) decides where that job's output goes once claimed. Run with `WORKER_RUNNER=local npm start` to process `local` jobs on your own machine; jobs with the other runner value are left untouched in the queue.

## Running with Docker (one-off)

```sh
docker build -t yt-processor .
docker run --env-file .env yt-processor
```

## Deploying to a VPS (perpetual worker)

Runs the worker continuously via Docker Compose with an automatic restart policy — suitable for a fresh VPS (Ubuntu + Docker Engine installed; Docker's systemd service is enabled by default).

1. Copy the repo to the VPS:
   ```sh
   git clone <repo-url> youtube-video-processor
   cd youtube-video-processor
   ```
2. Create `.env` from `.env.example` and fill in your Supabase credentials. Leave `WORKER_RUNNER=cloud` (the default) — this instance must only ever process `runner = 'cloud'` jobs:
   ```sh
   cp .env.example .env
   nano .env
   ```
3. Build and start the worker in the background:
   ```sh
   docker compose up -d --build
   ```
4. View logs:
   ```sh
   docker compose logs -f
   ```
5. Stop / restart:
   ```sh
   docker compose stop
   docker compose restart
   ```

### Updating / redeploying after a code change

```sh
git pull
docker compose up -d --build
```

This rebuilds the image and replaces the running container; `restart: unless-stopped` means it also comes back automatically after a VPS reboot.

### Runner scoping

Jobs are claimed via `claim_job(p_runner)`; this VPS worker passes `WORKER_RUNNER` (default `cloud`) as that filter, so it will only ever claim and process jobs where `runner = 'cloud'`. Jobs with `runner = 'local'` are left untouched in the queue for you to process manually on your own machine.
