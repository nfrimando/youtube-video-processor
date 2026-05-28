import { supabase } from './supabase.js';

export async function claimJob() {
  const { data, error } = await supabase.rpc('claim_job');
  if (error) throw error;
  return data?.id ? data : null;
}

export async function markDone(id, outputPath) {
  const { error } = await supabase
    .from('youtube_jobs')
    .update({ status: 'done', output_path: outputPath })
    .eq('id', id);
  if (error) throw error;
}

export async function markFailed(id, errorMsg) {
  const { error } = await supabase
    .from('youtube_jobs')
    .update({ status: 'failed', error: errorMsg })
    .eq('id', id);
  if (error) throw error;
}
