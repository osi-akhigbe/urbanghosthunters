-- Unify totems schema: drop the old totems/user_totems split and replace with
-- a single totems table that stores user ownership, type, and equipped state.
DROP TABLE IF EXISTS public.user_totems CASCADE;
DROP TABLE IF EXISTS public.totems CASCADE;

CREATE TABLE public.totems (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type        TEXT NOT NULL CHECK (type IN ('seal_stability', 'reveal_window', 'flash_cooldown')),
    equipped    BOOLEAN NOT NULL DEFAULT FALSE,
    effect_json JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.totems ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own totems"
    ON public.totems FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users insert own totems"
    ON public.totems FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own totems"
    ON public.totems FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users delete own totems"
    ON public.totems FOR DELETE
    USING (auth.uid() = user_id);
