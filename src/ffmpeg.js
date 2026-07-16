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
    '-vf', "drawtext=text='Analyze your game\nat padelsense.app':fontsize=h*0.025:fontcolor=white@0.6:x=w*0.75-tw/2:y=(h-th)/2:shadowcolor=black@0.4:shadowx=1:shadowy=1",
    '-c:v', 'libx264',
    '-preset', 'slow',
    '-crf', '18',
    '-c:a', 'copy',
    '-y',
    outputPath,
  ]);
}
