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

## Running with Docker

```sh
docker build -t yt-processor .
docker run --env-file .env yt-processor
```
