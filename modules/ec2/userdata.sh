#!/bin/bash
set -e

# Update system
yum update -y
yum install -y python3.11 python3.11-pip git postgresql15

# Install pip packages
pip3.11 install --upgrade pip
pip3.11 install \
  fastapi uvicorn \
  boto3 \
  psycopg2-binary pgvector \
  openai httpx \
  python-dotenv \
  anthropic

# Create app directory
mkdir -p /opt/governance-copilot
chown ec2-user:ec2-user /opt/governance-copilot

# Write environment file
cat > /opt/governance-copilot/.env << 'ENVEOF'
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
AWS_REGION=${aws_region}
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
BEDROCK_EMBEDDING_MODEL_ID=amazon.titan-embed-text-v2:0
ENVEOF

chown ec2-user:ec2-user /opt/governance-copilot/.env
chmod 600 /opt/governance-copilot/.env

# Write systemd service
cat > /etc/systemd/system/governance-copilot.service << 'SVCEOF'
[Unit]
Description=AWS Governance Copilot
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/governance-copilot
ExecStart=/usr/bin/python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
EnvironmentFile=/opt/governance-copilot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
# App will start once code is deployed — see deployment guide

echo "Bootstrap complete. Deploy app code to /opt/governance-copilot then: systemctl enable --now governance-copilot"
