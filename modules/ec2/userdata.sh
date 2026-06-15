#!/bin/bash
set -e

# ── System setup ──────────────────────────────────────────────
yum update -y
yum install -y python3.11 python3.11-pip git nginx

# ── PostgreSQL 15 + pgvector (replaces RDS — zero cost) ──────
# Install PostgreSQL 15 from official PGDG repo
dnf install -y postgresql15-server postgresql15-contrib

# Initialise the database cluster
postgresql-setup --initdb

# Enable and start PostgreSQL
systemctl enable postgresql
systemctl start postgresql

# Create database, user, and enable pgvector
sudo -u postgres psql << 'SQLEOF'
CREATE USER platform_admin WITH PASSWORD '${db_password}';
CREATE DATABASE cloud_security_platform OWNER platform_admin;
GRANT ALL PRIVILEGES ON DATABASE cloud_security_platform TO platform_admin;
SQLEOF

# Install pgvector extension from source (not in standard repos)
yum install -y gcc make postgresql15-devel git
cd /tmp
git clone --branch v0.6.0 https://github.com/pgvector/pgvector.git
cd pgvector
make
make install
cd /tmp && rm -rf pgvector

# Enable pgvector and create tables
sudo -u postgres psql -d cloud_security_platform << 'SQLEOF'
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS findings (
    id           SERIAL PRIMARY KEY,
    finding_id   TEXT UNIQUE NOT NULL,
    service      TEXT NOT NULL,
    severity     TEXT,
    title        TEXT NOT NULL,
    description  TEXT,
    resource_id  TEXT,
    region       TEXT,
    account_id   TEXT,
    raw_data     JSONB,
    collected_at TIMESTAMPTZ DEFAULT NOW(),
    embedding    vector(1536)
);
CREATE INDEX IF NOT EXISTS findings_service_idx   ON findings (service);
CREATE INDEX IF NOT EXISTS findings_severity_idx  ON findings (severity);
CREATE INDEX IF NOT EXISTS findings_collected_idx ON findings (collected_at DESC);

CREATE TABLE IF NOT EXISTS cost_anomalies (
    id           SERIAL PRIMARY KEY,
    anomaly_id   TEXT UNIQUE,
    service      TEXT,
    region       TEXT,
    amount_usd   NUMERIC(10,2),
    expected_usd NUMERIC(10,2),
    anomaly_date DATE,
    description  TEXT,
    collected_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS governance_chat_history (
    id SERIAL PRIMARY KEY, session_id TEXT NOT NULL,
    role TEXT NOT NULL, content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS discovery_sessions (
    id TEXT PRIMARY KEY, company_name TEXT NOT NULL DEFAULT 'Prospect',
    industry TEXT, company_size TEXT, scenario_id TEXT,
    status TEXT DEFAULT 'discovery',
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS discovery_messages (
    id SERIAL PRIMARY KEY, session_id TEXT NOT NULL,
    role TEXT NOT NULL, content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS gap_analysis_results (
    id SERIAL PRIMARY KEY, session_id TEXT NOT NULL,
    gaps JSONB NOT NULL DEFAULT '[]',
    maturity_scores JSONB NOT NULL DEFAULT '{}',
    overall_risk_level TEXT,
    compliance_status JSONB NOT NULL DEFAULT '{}',
    generated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recommendation_results (
    id SERIAL PRIMARY KEY, session_id TEXT NOT NULL,
    recommendations JSONB NOT NULL DEFAULT '[]',
    generated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS advanced_analysis (
    id SERIAL PRIMARY KEY, session_id TEXT NOT NULL,
    analysis_type TEXT NOT NULL, result JSONB NOT NULL,
    generated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Grant access to app user
GRANT ALL ON ALL TABLES IN SCHEMA public TO platform_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO platform_admin;
SQLEOF

# Allow platform_admin to connect via localhost password auth
echo "host  cloud_security_platform  platform_admin  127.0.0.1/32  md5" \
  >> /var/lib/pgsql/data/pg_hba.conf
systemctl reload postgresql

pip3.11 install --upgrade pip
pip3.11 install \
  fastapi uvicorn \
  boto3 \
  psycopg2-binary pgvector \
  openai httpx \
  python-dotenv \
  pydantic-settings \
  anthropic

# ── Shared environment ────────────────────────────────────────
cat > /etc/cloud-security-platform.env << 'ENVEOF'
DB_HOST=localhost
DB_PORT=5432
DB_NAME=cloud_security_platform
DB_USER=platform_admin
DB_PASSWORD=${db_password}
AWS_REGION=${aws_region}
S3_CACHE_BUCKET=${s3_cache_bucket}
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
BEDROCK_EMBEDDING_MODEL_ID=amazon.titan-embed-text-v2:0
FRONTEND_URL=http://localhost
ENVEOF
chmod 600 /etc/cloud-security-platform.env

# ── App directories ───────────────────────────────────────────
mkdir -p /opt/governance-copilot
mkdir -p /opt/discovery-copilot
chown ec2-user:ec2-user /opt/governance-copilot /opt/discovery-copilot

ln -sf /etc/cloud-security-platform.env /opt/governance-copilot/.env
ln -sf /etc/cloud-security-platform.env /opt/discovery-copilot/.env

# ── Governance Copilot — port 8000 ───────────────────────────
cat > /etc/systemd/system/governance-copilot.service << 'SVCEOF'
[Unit]
Description=AWS Governance Copilot
After=network.target postgresql.service

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/governance-copilot
ExecStart=/usr/bin/python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
Restart=always
RestartSec=5
EnvironmentFile=/etc/cloud-security-platform.env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=governance-copilot

[Install]
WantedBy=multi-user.target
SVCEOF

# ── Discovery Copilot — port 8001 ────────────────────────────
cat > /etc/systemd/system/discovery-copilot.service << 'SVCEOF'
[Unit]
Description=Security Discovery Copilot
After=network.target postgresql.service

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/discovery-copilot/backend
ExecStart=/usr/bin/python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8001 --workers 2
Restart=always
RestartSec=5
EnvironmentFile=/etc/cloud-security-platform.env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=discovery-copilot

[Install]
WantedBy=multi-user.target
SVCEOF

# ── Nginx reverse proxy ───────────────────────────────────────
cat > /etc/nginx/conf.d/cloud-security-platform.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    location /governance/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }

    location /discovery/ {
        proxy_pass http://127.0.0.1:8001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
        proxy_buffering off;
        proxy_cache off;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
    }

    location /health {
        return 200 '{"status":"ok","services":["governance-copilot","discovery-copilot"]}';
        add_header Content-Type application/json;
    }
}
NGINXEOF

systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

echo "Bootstrap complete — PostgreSQL running locally, all tables created."
