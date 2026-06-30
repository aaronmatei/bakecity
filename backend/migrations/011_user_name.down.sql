-- Migration: 011_user_name.down.sql
ALTER TABLE users DROP COLUMN IF EXISTS name;
