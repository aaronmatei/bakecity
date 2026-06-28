-- Migration: 002_production_media.up.sql
-- Phase 5: link production-timeline entries to an optional media attachment
-- (a presigned upload), so a baker's stage update can carry a progress photo.

ALTER TABLE production_updates
    ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES media(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_production_updates_media_id ON production_updates(media_id);
