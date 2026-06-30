-- Migration: 016_media_stage.up.sql
-- Scopes an uploaded media item to a named production stage and records its
-- mime type, so production photos/videos can be grouped per stage and the
-- client can tell a video from a photo. Both columns are optional/nullable.

ALTER TABLE media
    ADD COLUMN IF NOT EXISTS stage VARCHAR(50),
    ADD COLUMN IF NOT EXISTS mime_type VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_media_order_stage ON media(order_id, stage);
