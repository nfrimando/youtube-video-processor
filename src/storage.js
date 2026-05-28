import { readFile } from 'fs/promises';
import { supabase } from './supabase.js';

export async function uploadResult(localPath, storagePath) {
  const file = await readFile(localPath);
  const { error } = await supabase.storage
    .from('exports')
    .upload(storagePath, file, { contentType: 'video/mp4', upsert: true });
  if (error) throw new Error(`Storage upload failed: ${error.message}`);
  return supabase.storage.from('exports').getPublicUrl(storagePath).data.publicUrl;
}
