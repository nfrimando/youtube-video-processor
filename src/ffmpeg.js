import { execFile } from 'child_process';
import { promisify } from 'util';
import { writeFile } from 'fs/promises';

const exec = promisify(execFile);

export async function concat(clipPaths, outputPath) {
  const listPath = '/tmp/concat_list.txt';
  const content = clipPaths.map(p => `file '${p}'`).join('\n');
  await writeFile(listPath, content);
  await exec('ffmpeg', [
    '-f', 'concat',
    '-safe', '0',
    '-i', listPath,
    '-c', 'copy',
    '-y',
    outputPath,
  ]);
}
