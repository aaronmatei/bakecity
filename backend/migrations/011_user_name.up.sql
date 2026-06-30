-- Migration: 011_user_name.up.sql
-- Adds an optional personal name to users so reviews, chat and greetings can
-- show a real name instead of a generic placeholder.

ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(255);
