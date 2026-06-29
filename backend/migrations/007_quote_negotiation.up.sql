-- Negotiation: quotes can now be proposed by the customer (a suggested offer)
-- as well as the baker, and a baker quote can be flagged as their best & final.
ALTER TABLE quotes
    ADD COLUMN IF NOT EXISTS proposed_by VARCHAR(20) NOT NULL DEFAULT 'baker';
ALTER TABLE quotes
    ADD COLUMN IF NOT EXISTS is_final BOOLEAN NOT NULL DEFAULT false;
