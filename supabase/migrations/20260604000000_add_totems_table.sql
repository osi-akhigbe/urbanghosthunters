-- Totems: equippable items that modify gameplay mechanics
DROP TABLE IF EXISTS totems CASCADE;
CREATE TABLE totems (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type        TEXT NOT NULL CHECK (type IN ('seal_stability', 'reveal_window', 'flash_cooldown')),
    equipped    BOOLEAN NOT NULL DEFAULT FALSE,
    effect_json JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE totems ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own totems"
    ON totems FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users insert own totems"
    ON totems FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own totems"
    ON totems FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users delete own totems"
    ON totems FOR DELETE
    USING (auth.uid() = user_id);
