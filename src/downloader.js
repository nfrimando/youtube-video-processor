import { execFile } from 'child_process';
import { promisify } from 'util';

const exec = promisify(execFile);

export async function downloadClip(url, start, end, outPath) {
  await exec('yt-dlp', [
    '--download-sections', `*${start}-${end}`,
    '--force-keyframes-at-cuts',
    '-f', 'mp4',
    '-o', outPath,
    url,
  ]);
}
