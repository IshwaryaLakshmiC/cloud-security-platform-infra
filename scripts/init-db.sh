#!/bin/bash
# init-db.sh — Run after terraform apply to initialise the database
# Usage: bash scripts/init-db.sh
# Requires: psql, terraform outputs available in environments/dev

set -e

echo "==> Getting RDS endpoint from Terraform outputs..."
cd environments/dev
DB_HOST=$(terraform output -raw rds_host)
DB_NAME=$(terraform output -raw rds_host | sed 's/:.*//')
cd ../..

echo "DB Host: $DB_HOST"
echo ""
echo "==> Enter your RDS password when prompted"

# Install pgvector extension and create schema
psql "host=$DB_HOST port=5432 dbname=governance_copilot user=copilot_admin sslmode=require" << 'SQL'

-- Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Findings table — stores all AWS security/cost findings
CREATE TABLE IF NOT EXISTS findings (
    id          SERIAL PRIMARY KEY,
    finding_id  TEXT UNIQUE NOT NULL,
    service     TEXT NOT NULL,          -- iam, s3, ec2, guardduty, cloudtrail, rds, lambda, cost
    severity    TEXT,                   -- critical, high, medium, low, info
    title       TEXT NOT NULL,
    description TEXT,
    resource_id TEXT,
    region      TEXT,
    account_id  TEXT,
    raw_data    JSONB,
    collected_at TIMESTAMPTZ DEFAULT NOW(),
    embedding   vector(1536)            -- Titan Embeddings V2 dimension
);

-- Index for vector similarity search
CREATE INDEX IF NOT EXISTS findings_embedding_idx
    ON findings USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Index for metadata filtering
CREATE INDEX IF NOT EXISTS findings_service_idx ON findings (service);
CREATE INDEX IF NOT EXISTS findings_severity_idx ON findings (severity);
CREATE INDEX IF NOT EXISTS findings_collected_at_idx ON findings (collected_at DESC);

-- Cost anomalies table
CREATE TABLE IF NOT EXISTS cost_anomalies (
    id              SERIAL PRIMARY KEY,
    anomaly_id      TEXT UNIQUE,
    service         TEXT,
    region          TEXT,
    amount_usd      NUMERIC(10,2),
    expected_usd    NUMERIC(10,2),
    anomaly_date    DATE,
    description     TEXT,
    collected_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Chat history table (for conversation context)
CREATE TABLE IF NOT EXISTS chat_history (
    id          SERIAL PRIMARY KEY,
    session_id  TEXT NOT NULL,
    role        TEXT NOT NULL,   -- user, assistant
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS chat_history_session_idx ON chat_history (session_id, created_at DESC);

SELECT 'Database initialised successfully' AS status;
SELECT 'pgvector version: ' || extversion AS pgvector FROM pg_extension WHERE extname = 'vector';
SQL

echo ""
echo "==> Database initialised. pgvector is ready."
echo "==> Next: deploy the app to your EC2 instance."
