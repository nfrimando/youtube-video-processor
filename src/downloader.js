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

  let authenticated = true;
  if (process.env.COOKIES_FILE) {
    args.push('--cookies', process.env.COOKIES_FILE);
  } else if (process.env.COOKIES_FROM_BROWSER) {
    args.push('--cookies-from-browser', process.env.COOKIES_FROM_BROWSER);
  } else {
    authenticated = false;
  }

  // yt-dlp's default client (android_vr) is the only one that serves full formats
  // anonymously, but it cannot authenticate: pair it with cookies and googlevideo 403s
  // every media request, including the ranged ones ffmpeg makes for --download-sections.
  // web_embedded serves full formats for a signed-in session.
  const playerClient = process.env.YTDLP_PLAYER_CLIENT ?? (authenticated ? 'web_embedded' : null);
  if (playerClient) {
    args.push('--extractor-args', `youtube:player_client=${playerClient}`);
  }

  args.push(url);
  console.log('[yt-dlp] args:', args.join(' '));
  await exec('yt-dlp', args);
}
