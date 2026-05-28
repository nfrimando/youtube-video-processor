import { mkdirSync } from 'fs';
import { downloadClip } from './src/downloader.js';
import { concat } from './src/ffmpeg.js';

// Args come in triplets: url start end [url start end ...]
const args = process.argv.slice(2);
if (args.length === 0 || args.length % 3 !== 0) {
  console.error('Usage: node test-download.js <url> <start> <end> [<url> <start> <end> ...]');
  process.exit(1);
}

const clips = [];
for (let i = 0; i < args.length; i += 3) {
  clips.push({ url: args[i], start: args[i + 1], end: args[i + 2] });
}

const dir = '/tmp/yt-test';
mkdirSync(dir, { recursive: true });

const clipPaths = [];
for (let i = 0; i < clips.length; i++) {
  const { url, start, end } = clips[i];
  const clipPath = `${dir}/clip-${i}.mp4`;
  console.log(`[${i + 1}/${clips.length}] Downloading ${url} [${start} → ${end}]...`);
  await downloadClip(url, start, end, clipPath);
  clipPaths.push(clipPath);
}

const outPath = `${dir}/output.mp4`;
console.log('Concatenating...');
await concat(clipPaths, outPath);
console.log(`Done! Output: ${outPath}`);
