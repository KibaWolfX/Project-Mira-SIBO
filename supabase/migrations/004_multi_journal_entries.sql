-- Migration 004: Allow multiple journal entries per day
-- Run AFTER 001, 002, 003

-- Add entry_id and time columns
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS entry_id TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS time TEXT DEFAULT '12:00';

-- Backfill entry_id for existing rows (use the UUID id as fallback)
UPDATE journal_entries SET entry_id = id::text WHERE entry_id IS NULL;

-- Drop the old unique constraint (one entry per user per day)
ALTER TABLE journal_entries DROP CONSTRAINT IF EXISTS journal_entries_user_id_date_key;

-- Add new unique constraint (one entry per user per entry_id)
ALTER TABLE journal_entries ADD CONSTRAINT journal_entries_user_id_entry_id_key UNIQUE(user_id, entry_id);

-- Keep the date index for efficient date-range queries
-- (idx_journal_user_date already exists from migration 001)
