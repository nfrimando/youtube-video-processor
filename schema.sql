-- youtube_jobs table
-- Stores clip export jobs. Each job belongs to a session and may reference
-- one or more events the user selected for export.
CREATE TABLE IF NOT EXISTS public.youtube_jobs (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  uuid        NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  type        text        NOT NULL DEFAULT 'clip_export',
  status      text        NOT NULL DEFAULT 'queued',
  clips       jsonb       NOT NULL,  -- [{url, start, end}] resolved at job creation time
  event_ids   uuid[]      NULL,      -- source event IDs the user selected (for UI reference)
  output_path text,
  error       text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT youtube_jobs_type_check   CHECK (type   IN ('clip_export')),
  CONSTRAINT youtube_jobs_status_check CHECK (status IN ('queued', 'processing', 'done', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_youtube_jobs_queued_order
  ON public.youtube_jobs (created_at)
  WHERE status = 'queued';

CREATE INDEX IF NOT EXISTS idx_youtube_jobs_session_id
  ON public.youtube_jobs (session_id);

CREATE TRIGGER update_youtube_jobs_updated_at
BEFORE UPDATE ON public.youtube_jobs
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- claim_job() function — called by the worker via supabase.rpc('claim_job').
-- Atomically claims the oldest queued job and flips it to processing.
-- Returns NULL when no queued job is available.
CREATE OR REPLACE FUNCTION public.claim_job()
RETURNS public.youtube_jobs
LANGUAGE plpgsql
AS $$
DECLARE
  claimed public.youtube_jobs;
BEGIN
  SELECT * INTO claimed
  FROM public.youtube_jobs
  WHERE status = 'queued'
  ORDER BY created_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  UPDATE public.youtube_jobs
  SET status = 'processing', updated_at = now()
  WHERE id = claimed.id
  RETURNING * INTO claimed;

  RETURN claimed;
END;
$$;


-- Test job — inserts one job from your most recent session + its first timed event.
-- Run this in the SQL editor to queue a job for manual testing.
-- INSERT INTO youtube_jobs (session_id, type, clips, event_ids)
-- SELECT
--   s.id,
--   'clip_export',
--   jsonb_build_array(
--     jsonb_build_object(
--       'url',   s.youtube_url,
--       'start', e.timestamp_seconds_start,
--       'end',   e.timestamp_seconds_end
--     )
--   ),
--   ARRAY[e.id]
-- FROM sessions s
-- JOIN events e ON e.session_id = s.id
-- WHERE e.timestamp_seconds_end IS NOT NULL
-- ORDER BY s.created_at DESC, e.created_at
-- LIMIT 1;
