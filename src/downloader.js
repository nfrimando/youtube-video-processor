import { execFile } from 'child_process';
import { promisify } from 'util';

const exec = promisify(execFile);

export async function downloadClip(url, start, end, outPath) {
  const args = [
    '--download-sections', `*${start}-${end}`,
    '--force-keyframes-at-cuts',
    '-f', 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]',
    '--merge-output-format', 'mp4',
    '-o', outPath,
  ];

  if (process.env.COOKIES_FILE) {
    args.push('--cookies', process.env.COOKIES_FILE);
  } else if (process.env.COOKIES_FROM_BROWSER) {
    args.push('--cookies-from-browser', process.env.COOKIES_FROM_BROWSER);
  }

  args.push(url);
  console.log('[yt-dlp] args:', args.join(' '));
  await exec('yt-dlp', args);
}
