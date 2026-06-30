-- Migration: 015_allow_custom_request.down.sql
ALTER TABLE products DROP COLUMN IF EXISTS allow_custom_request;
