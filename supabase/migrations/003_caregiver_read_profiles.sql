-- Fix: Allow caregivers to read their linked patient's profile
-- Run this in Supabase SQL Editor AFTER 001 and 002

-- Caregivers can read their patient's profile
CREATE POLICY "Caregivers can read patient profile"
  ON profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM caregiver_links
      WHERE caregiver_id = auth.uid()
        AND patient_id = profiles.id
        AND status = 'active'
    )
  );
