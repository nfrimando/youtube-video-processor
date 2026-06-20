-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.contexts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type text NOT NULL,
  body text NOT NULL,
  version integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT contexts_pkey PRIMARY KEY (id)
);
CREATE TABLE public.event_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  session_id uuid NOT NULL,
  author_id uuid NOT NULL,
  parent_id uuid,
  body text NOT NULL CHECK (char_length(body) >= 1 AND char_length(body) <= 1000),
  edited_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT event_comments_pkey PRIMARY KEY (id),
  CONSTRAINT event_comments_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT event_comments_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id),
  CONSTRAINT event_comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id),
  CONSTRAINT event_comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.event_comments(id)
);
CREATE TABLE public.event_likes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  session_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT event_likes_pkey PRIMARY KEY (id),
  CONSTRAINT event_likes_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT event_likes_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id),
  CONSTRAINT event_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  event_type text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  player_id integer NOT NULL,
  target_player_id integer,
  updated_at timestamp with time zone DEFAULT now(),
  set_number integer NOT NULL DEFAULT 1,
  game_number integer NOT NULL DEFAULT 1,
  logged_by text,
  timestamp_seconds_start double precision NOT NULL,
  timestamp_seconds_end double precision,
  CONSTRAINT events_pkey PRIMARY KEY (id),
  CONSTRAINT events_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id),
  CONSTRAINT events_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(player_id),
  CONSTRAINT events_target_player_fkey FOREIGN KEY (target_player_id) REFERENCES public.players(player_id),
  CONSTRAINT events_logged_by_fkey FOREIGN KEY (logged_by) REFERENCES public.profiles(email)
);
CREATE TABLE public.players (
  player_id integer NOT NULL DEFAULT nextval('players_player_id_seq'::regclass),
  player_name text NOT NULL,
  email text UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  nickname text,
  created_by text,
  image_url text,
  normalized_player_name text DEFAULT normalize_player_name(player_name),
  email_unsubscribed boolean NOT NULL DEFAULT false,
  CONSTRAINT players_pkey PRIMARY KEY (player_id),
  CONSTRAINT players_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(email)
);
CREATE TABLE public.profile_claims (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  claimant_email text NOT NULL,
  player_id integer NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profile_claims_pkey PRIMARY KEY (id),
  CONSTRAINT profile_claims_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(player_id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  full_name text,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.request_players (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL,
  position integer NOT NULL CHECK ("position" >= 1 AND "position" <= 4),
  player_id integer,
  player_name text NOT NULL,
  CONSTRAINT request_players_pkey PRIMARY KEY (id),
  CONSTRAINT request_players_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.requests(id),
  CONSTRAINT request_players_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(player_id)
);
CREATE TABLE public.requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_type USER-DEFINED NOT NULL DEFAULT 'analytics'::request_type,
  status USER-DEFINED NOT NULL DEFAULT 'submitted'::request_status,
  requester_id uuid NOT NULL,
  assigned_to_id uuid,
  youtube_url text NOT NULL,
  youtube_video_id text NOT NULL,
  match_date date,
  venue text,
  notes text,
  is_paid boolean NOT NULL DEFAULT false,
  session_id uuid,
  submitted_at timestamp with time zone NOT NULL DEFAULT now(),
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  claimed_by_id uuid,
  claimed_at timestamp with time zone,
  payment_amount numeric,
  CONSTRAINT requests_pkey PRIMARY KEY (id),
  CONSTRAINT requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.profiles(id),
  CONSTRAINT requests_assigned_to_id_fkey FOREIGN KEY (assigned_to_id) REFERENCES public.service_providers(id),
  CONSTRAINT requests_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id),
  CONSTRAINT requests_claimed_by_id_fkey FOREIGN KEY (claimed_by_id) REFERENCES public.service_providers(id)
);
CREATE TABLE public.service_providers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL UNIQUE,
  type USER-DEFINED NOT NULL DEFAULT 'analyst'::service_provider_type,
  display_name text NOT NULL,
  bio text,
  avatar_url text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT service_providers_pkey PRIMARY KEY (id),
  CONSTRAINT service_providers_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.session_access (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  user_id uuid NOT NULL,
  access_level text NOT NULL CHECK (access_level = ANY (ARRAY['view'::text, 'edit'::text])),
  granted_at timestamp with time zone DEFAULT now(),
  CONSTRAINT session_access_pkey PRIMARY KEY (id),
  CONSTRAINT session_access_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id),
  CONSTRAINT session_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.session_players (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  player_id integer NOT NULL,
  position integer NOT NULL CHECK ("position" >= 1 AND "position" <= 4),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT session_players_pkey PRIMARY KEY (id),
  CONSTRAINT fk_session FOREIGN KEY (session_id) REFERENCES public.sessions(id),
  CONSTRAINT fk_player FOREIGN KEY (player_id) REFERENCES public.players(player_id)
);
CREATE TABLE public.session_set_servers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  set_number integer NOT NULL,
  serving_order ARRAY NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT session_set_servers_pkey PRIMARY KEY (id),
  CONSTRAINT session_set_servers_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id)
);
CREATE TABLE public.sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  youtube_url text NOT NULL,
  youtube_video_id text NOT NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'live'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  owner_id uuid,
  edit_mode text NOT NULL DEFAULT 'owner_only'::text CHECK (edit_mode = ANY (ARRAY['owner_only'::text, 'invite_only'::text, 'public_edit'::text])),
  match_date date,
  venue text,
  synthesis text,
  synthesis_generated_at timestamp with time zone,
  additional_context text,
  synthesis_generation_count integer NOT NULL DEFAULT 0,
  event_logger_type text NOT NULL DEFAULT 'classic'::text CHECK (event_logger_type = ANY (ARRAY['classic'::text, 'range'::text])),
  CONSTRAINT sessions_pkey PRIMARY KEY (id),
  CONSTRAINT sessions_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.youtube_jobs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  type text NOT NULL DEFAULT 'clip_export'::text CHECK (type = 'clip_export'::text),
  status text NOT NULL DEFAULT 'queued'::text CHECK (status = ANY (ARRAY['queued'::text, 'processing'::text, 'done'::text, 'failed'::text])),
  clips jsonb NOT NULL,
  event_ids ARRAY,
  output_path text,
  error text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  youtube_url text,
  deleted_at timestamp with time zone,
  name text,
  requested_by text,
  duration_seconds integer,
  runner text NOT NULL DEFAULT 'cloud'::text CHECK (runner = ANY (ARRAY['cloud'::text, 'local'::text])),
  is_excluded_from_limit boolean NOT NULL DEFAULT false,
  CONSTRAINT youtube_jobs_pkey PRIMARY KEY (id),
  CONSTRAINT youtube_jobs_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id)
);