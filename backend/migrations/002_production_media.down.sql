-- Migration: 002_production_media.down.sql

DROP INDEX IF EXISTS idx_production_updates_media_id;

ALTER TABLE production_updates
    DROP COLUMN IF EXISTS media_id;
