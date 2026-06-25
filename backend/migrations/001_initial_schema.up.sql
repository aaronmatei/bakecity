-- Migration: 001_initial_schema.up.sql
-- Creates the full BakeCity schema.

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS postgis;  -- geography(point)

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_mask INT NOT NULL DEFAULT 0, -- bitmask: 1=customer, 2=baker, 4=admin
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(255) UNIQUE,
    phone_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- User credentials (password hashes kept separate from the user record)
CREATE TABLE IF NOT EXISTS user_credentials (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Baker profiles
CREATE TABLE IF NOT EXISTS baker_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    business_name VARCHAR(255) NOT NULL,
    bio TEXT,
    location GEOGRAPHY(POINT, 4326),
    delivery_radius_km DECIMAL(5,2) DEFAULT 10,
    status VARCHAR(50) DEFAULT 'pending', -- pending, approved, suspended
    kyc_status VARCHAR(50) DEFAULT 'pending',
    lead_time_days INT DEFAULT 1,
    daily_order_capacity INT DEFAULT 10,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Baker blackout dates
CREATE TABLE IF NOT EXISTS baker_blackout_dates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baker_id UUID NOT NULL REFERENCES baker_profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    reason VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(baker_id, date)
);

-- Product categories
CREATE TABLE IF NOT EXISTS product_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Products
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baker_id UUID NOT NULL REFERENCES baker_profiles(id) ON DELETE CASCADE,
    category_id UUID REFERENCES product_categories(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    base_price NUMERIC(12,2) NOT NULL,
    lead_time_days INT DEFAULT 1,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Media (uploads: reference photos, production photos, delivery proof)
CREATE TABLE IF NOT EXISTS media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind VARCHAR(50) NOT NULL, -- reference, production, delivery_proof, product
    s3_key TEXT NOT NULL,
    thumb_key TEXT,
    status VARCHAR(50) DEFAULT 'pending', -- pending, uploaded, ready
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Product images (join media to products)
CREATE TABLE IF NOT EXISTS product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    position INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, media_id)
);

-- Orders
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES users(id),
    baker_id UUID NOT NULL REFERENCES baker_profiles(id),
    product_id UUID REFERENCES products(id),
    status VARCHAR(40) NOT NULL DEFAULT 'DRAFT',
    -- state machine: DRAFT, QUOTE_REQUESTED, NEGOTIATING, QUOTED, APPROVED,
    -- DEPOSIT_PENDING, DEPOSIT_PAID, IN_PRODUCTION, READY, OUT_FOR_DELIVERY,
    -- DELIVERED, COMPLETED, CANCELLED, DISPUTED, REFUNDED
    event_date DATE,
    delivery_address TEXT,
    delivery_location GEOGRAPHY(POINT, 4326),
    total_amount NUMERIC(12,2) DEFAULT 0,
    deposit_amount NUMERIC(12,2) DEFAULT 0,
    balance_amount NUMERIC(12,2) DEFAULT 0,
    commission_amount NUMERIC(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Order specs (free-form key/value spec attributes)
CREATE TABLE IF NOT EXISTS order_specs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    key VARCHAR(255) NOT NULL,
    value TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Quotes (versioned per order)
CREATE TABLE IF NOT EXISTS quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    version INT NOT NULL DEFAULT 1,
    amount NUMERIC(12,2) NOT NULL,
    deposit_pct NUMERIC(5,2) NOT NULL DEFAULT 50,
    valid_until TIMESTAMPTZ,
    status VARCHAR(40) NOT NULL DEFAULT 'pending', -- pending, accepted, expired, rejected
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(order_id, version)
);

-- Message threads (one per order)
CREATE TABLE IF NOT EXISTS message_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Messages
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES message_threads(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id),
    body TEXT,
    media_id UUID REFERENCES media(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Production updates
CREATE TABLE IF NOT EXISTS production_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    stage VARCHAR(100) NOT NULL,
    progress_pct INT DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Deliveries
CREATE TABLE IF NOT EXISTS deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    method VARCHAR(50) NOT NULL, -- pickup, courier, self
    courier_ref VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending', -- pending, dispatched, delivered, confirmed
    proof_media_id UUID REFERENCES media(id),
    dispatched_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),
    kind VARCHAR(20) NOT NULL, -- deposit, balance, refund
    psp_ref VARCHAR(255),
    amount NUMERIC(12,2) NOT NULL,
    status VARCHAR(40) DEFAULT 'pending', -- pending, succeeded, failed
    idempotency_key VARCHAR(255) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Ledger accounts (double-entry escrow accounting)
CREATE TABLE IF NOT EXISTS ledger_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind VARCHAR(40) NOT NULL, -- customer, baker_pending, baker_available, platform_revenue, refunds
    owner_id UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(kind, owner_id)
);

-- Transactions (group balanced ledger entries)
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind VARCHAR(40) NOT NULL,
    order_id UUID REFERENCES orders(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Ledger entries (legs of a transaction)
CREATE TABLE IF NOT EXISTS ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    txn_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES ledger_accounts(id),
    debit NUMERIC(12,2) NOT NULL DEFAULT 0,
    credit NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Payouts (disbursements to bakers)
CREATE TABLE IF NOT EXISTS payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baker_id UUID NOT NULL REFERENCES baker_profiles(id),
    amount NUMERIC(12,2) NOT NULL,
    psp_ref VARCHAR(255),
    status VARCHAR(40) DEFAULT 'pending', -- pending, processing, paid, failed
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Disputes
CREATE TABLE IF NOT EXISTS disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    raised_by UUID NOT NULL REFERENCES users(id),
    reason TEXT NOT NULL,
    status VARCHAR(40) DEFAULT 'open', -- open, resolved, rejected
    resolution TEXT,
    refund_amount NUMERIC(12,2),
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Reviews
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),
    customer_id UUID NOT NULL REFERENCES users(id),
    baker_id UUID NOT NULL REFERENCES baker_profiles(id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    body TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(order_id, customer_id)
);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel VARCHAR(20) NOT NULL, -- push, sms, in_app
    type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_baker_profiles_user_id ON baker_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_baker_profiles_location ON baker_profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_products_baker_id ON products(baker_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_media_order_id ON media(order_id);
CREATE INDEX IF NOT EXISTS idx_media_owner_id ON media(owner_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_baker_id ON orders(baker_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_location ON orders USING GIST(delivery_location);
CREATE INDEX IF NOT EXISTS idx_order_specs_order_id ON order_specs(order_id);
CREATE INDEX IF NOT EXISTS idx_quotes_order_id ON quotes(order_id);
CREATE INDEX IF NOT EXISTS idx_messages_thread_id ON messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_production_updates_order_id ON production_updates(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_order_id ON deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_idempotency_key ON payments(idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ledger_entries_account_id ON ledger_entries(account_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_txn_id ON ledger_entries(txn_id);
CREATE INDEX IF NOT EXISTS idx_transactions_order_id ON transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_payouts_baker_id ON payouts(baker_id);
CREATE INDEX IF NOT EXISTS idx_disputes_order_id ON disputes(order_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_reviews_baker_id ON reviews(baker_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
