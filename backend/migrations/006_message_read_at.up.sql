-- Read receipts: when a participant opens a thread, the counterparty's messages
-- are stamped read_at, so the sender can see delivery/read status.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
