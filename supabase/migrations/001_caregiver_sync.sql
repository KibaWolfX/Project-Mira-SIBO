-- Caregiver sync tables for Mira's SIBO Toolkit
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New Query)

-- 1. Journal entries synced from localStorage
CREATE TABLE IF NOT EXISTS journal_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  severity INT CHECK (severity BETWEEN 1 AND 5),
  symptoms TEXT[] DEFAULT '{}',
  notes TEXT DEFAULT '',
  medications_taken TEXT[] DEFAULT '{}',
  migraine JSONB DEFAULT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, date)
);

-- 2. Medications synced from localStorage
CREATE TABLE IF NOT EXISTS medications (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  type TEXT DEFAULT 'other',
  dose TEXT DEFAULT '',
  frequency TEXT DEFAULT '',
  start_date DATE,
  end_date DATE,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Caregiver-patient links
CREATE TABLE IF NOT EXISTS caregiver_links (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  invite_code TEXT UNIQUE,
  status TEXT DEFAULT 'active' CHECK (status IN ('pending', 'active', 'revoked')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(caregiver_id, patient_id)
);

-- 4. Row-level security policies

-- Journal: users can read/write their own entries
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own journal entries"
  ON journal_entries FOR ALL
  USING (auth.uid() = user_id);

-- Caregivers can read their patient's journal entries
CREATE POLICY "Caregivers can read patient journal"
  ON journal_entries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM caregiver_links
      WHERE caregiver_id = auth.uid()
        AND patient_id = journal_entries.user_id
        AND status = 'active'
    )
  );

-- Medications: users can read/write their own
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own medications"
  ON medications FOR ALL
  USING (auth.uid() = user_id);

-- Caregivers can read their patient's medications
CREATE POLICY "Caregivers can read patient medications"
  ON medications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM caregiver_links
      WHERE caregiver_id = auth.uid()
        AND patient_id = medications.user_id
        AND status = 'active'
    )
  );

-- Caregiver links: both parties can read, caregiver can create
ALTER TABLE caregiver_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can see their own links"
  ON caregiver_links FOR SELECT
  USING (auth.uid() = caregiver_id OR auth.uid() = patient_id);

CREATE POLICY "Patients can create links with invite codes"
  ON caregiver_links FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Either party can update link status"
  ON caregiver_links FOR UPDATE
  USING (auth.uid() = caregiver_id OR auth.uid() = patient_id);

-- 5. Index for fast caregiver lookups
CREATE INDEX IF NOT EXISTS idx_journal_user_date ON journal_entries(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_meds_user ON medications(user_id);
CREATE INDEX IF NOT EXISTS idx_caregiver_links ON caregiver_links(caregiver_id, status);
CREATE INDEX IF NOT EXISTS idx_caregiver_invite ON caregiver_links(invite_code) WHERE invite_code IS NOT NULL;
