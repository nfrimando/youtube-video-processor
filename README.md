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

## Running with Docker

```sh
docker build -t yt-processor .
docker run --env-file .env yt-processor
```
