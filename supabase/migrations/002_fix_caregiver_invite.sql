-- Fix: Allow pending invites to be claimed by any authenticated user
-- Run this in Supabase SQL Editor AFTER 001_caregiver_sync.sql

-- 1. Make caregiver_id nullable (NULL = unclaimed invite)
ALTER TABLE caregiver_links ALTER COLUMN caregiver_id DROP NOT NULL;

-- 2. Drop the unique constraint that breaks with NULL caregiver_id
ALTER TABLE caregiver_links DROP CONSTRAINT IF EXISTS caregiver_links_caregiver_id_patient_id_key;

-- 3. Drop old restrictive policies
DROP POLICY IF EXISTS "Users can see their own links" ON caregiver_links;
DROP POLICY IF EXISTS "Patients can create links with invite codes" ON caregiver_links;
DROP POLICY IF EXISTS "Either party can update link status" ON caregiver_links;

-- 4. New policies that allow invite flow to work

-- Users can see their own active links
CREATE POLICY "Users can see own links"
  ON caregiver_links FOR SELECT
  USING (
    auth.uid() = caregiver_id
    OR auth.uid() = patient_id
  );

-- Any authenticated user can see pending invites by code (for claiming)
CREATE POLICY "Anyone can find pending invites"
  ON caregiver_links FOR SELECT
  USING (
    status = 'pending' AND invite_code IS NOT NULL
  );

-- Patients can create invites (caregiver_id is NULL initially)
CREATE POLICY "Patients can create invites"
  ON caregiver_links FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

-- Any authenticated user can claim a pending invite (update caregiver_id)
CREATE POLICY "Anyone can claim pending invite"
  ON caregiver_links FOR UPDATE
  USING (
    status = 'pending' AND invite_code IS NOT NULL
  );

-- Either party can update active links (e.g., revoke)
CREATE POLICY "Linked users can update"
  ON caregiver_links FOR UPDATE
  USING (
    auth.uid() = caregiver_id OR auth.uid() = patient_id
  );
