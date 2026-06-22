# Urban Ghost Hunters — Setup Guide

## Prerequisites
- Xcode 15+
- Supabase CLI v2.98+
- A Supabase account

## Getting Started

### 1. Clone the repo
```bash
git clone <repo-url>
cd urbanghosthunters
```

### 2. Create your Secrets.plist
Create a `Secrets.plist` file in the `ios/urbanghosthunters/` folder with the following keys:

| Key | Value |
|-----|-------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Your Supabase anon key |

Find these in your Supabase dashboard under **Project Settings → API**.

> ⚠️ Never commit `Secrets.plist` — it is in `.gitignore`

### 3. Link Supabase CLI
```bash
supabase link --project-ref <your-project-ref>
```

### 4. Apply migrations
```bash
supabase db push
```

This applies all migrations in `supabase/migrations/` to your Supabase project.

## Migration Workflow
All schema changes must go through migrations — no manual SQL edits in the Supabase dashboard.

### Creating a new migration
```bash
supabase migration new <description>
```

This creates a new file in `supabase/migrations/`. Add your SQL there, then run:
```bash
supabase db push
```

### Current migrations
| Migration | Description |
|-----------|-------------|
| `add_totems_table` | Creates `totems` and `user_totems` tables with RLS |
| `add_analytics_events_table` | Creates `events` table for analytics |

## Supabase Auth
Anonymous sign-ins must be enabled in your Supabase dashboard under **Authentication → Providers → Anonymous Sign-ins**.