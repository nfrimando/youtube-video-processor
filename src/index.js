import { claimJob, markDone, markFailed } from './jobs.js';
import { downloadClip } from './downloader.js';
import { concat } from './ffmpeg.js';
import { uploadResult } from './storage.js';
import { rm, mkdir } from 'fs/promises';

const POLL_INTERVAL_MS = 10_000;

async function processJob(job) {
  const workDir = `/tmp/job_${job.id}`;
  await mkdir(workDir, { recursive: true });

  try {
    const clips = job.clips; // [{url, start, end}, ...]
    const clipPaths = [];

    for (let i = 0; i < clips.length; i++) {
      const { url, start, end } = clips[i];
      const outPath = `${workDir}/clip_${i}.mp4`;
      console.log(`[${job.id}] Downloading clip ${i + 1}/${clips.length}: ${url} (${start}–${end})`);
      await downloadClip(url, start, end, outPath);
      clipPaths.push(outPath);
    }

    const outputPath = `${workDir}/output.mp4`;
    console.log(`[${job.id}] Concatenating ${clipPaths.length} clips…`);
    await concat(clipPaths, outputPath);

    const storagePath = `${job.id}.mp4`;
    console.log(`[${job.id}] Uploading to Supabase Storage…`);
    const publicUrl = await uploadResult(outputPath, storagePath);

    console.log(`[${job.id}] Done: ${publicUrl}`);
    return publicUrl;
  } finally {
    await rm(workDir, { recursive: true, force: true });
  }
}

async function main() {
  console.log('Worker started — polling for jobs every', POLL_INTERVAL_MS / 1000, 'seconds');

  while (true) {
    try {
      const job = await claimJob();

      if (job) {
        console.log(`[${job.id}] Claimed job`);
        try {
          const outputUrl = await processJob(job);
          await markDone(job.id, outputUrl);
        } catch (err) {
          console.error(`[${job.id}] Failed:`, err.message);
          await markFailed(job.id, err.message);
        }
      } else {
        await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
      }
    } catch (err) {
      console.error('Unexpected error in poll loop:', err.message);
      await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
    }
  }
}

main();
