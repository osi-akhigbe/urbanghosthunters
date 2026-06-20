-- NFC totem/key tags table
-- uid: uppercase hex UID with no separators, e.g. 04ABCDEF123456
-- totem_type: links to totems.type; null when the tag is a hotspot key
-- key_name: freeform identifier for hotspot-unlock keys; null for totem tags
-- label: human-readable name shown to the player on a successful scan

create table if not exists nfc_tags (
    id          uuid        primary key default gen_random_uuid(),
    uid         text        not null unique,
    totem_type  text        references totems(type),
    key_name    text,
    label       text        not null,
    created_at  timestamptz default now(),
    constraint totem_or_key check (
        (totem_type is not null and key_name is null)
        or (totem_type is null and key_name is not null)
    )
);

alter table nfc_tags enable row level security;

create policy "nfc_tags_read_all" on nfc_tags
    for select using (true);

-- Seed data for development / field testing
insert into nfc_tags (uid, totem_type, label) values
    ('04ABCDEF123456', 'seal_stability', 'Ancient Seal Stone'),
    ('04FEDCBA654321', 'reveal_window',  'Spirit Lens Pendant'),
    ('04112233445566', 'flash_cooldown', 'Thunder Charm')
on conflict (uid) do nothing;
