-- Migration: 016_media_stage.down.sql

DROP INDEX IF EXISTS idx_media_order_stage;

ALTER TABLE media
    DROP COLUMN IF EXISTS stage,
    DROP COLUMN IF EXISTS mime_type;
