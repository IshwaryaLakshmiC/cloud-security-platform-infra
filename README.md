# AWS Governance Copilot — Infrastructure (Terraform)

> **Terraform codebase for the AWS Security & Cost Governance Copilot** — provisions all AWS infrastructure needed to run the AI-powered governance assistant against your real AWS account.

Part of the [AWS Governance Copilot](https://github.com/IshwaryaLakshmiC/aws-governance-copilot) project.  
Built by [Ishwarya Lakshmi C](https://github.com/IshwaryaLakshmiC) · [ishwaryaaunfiltered.live](https://ishwaryaaunfiltered.live)

---

## What this provisions

All resources are **free tier eligible** in `us-east-1`.

| Resource | Purpose | Free tier |
|----------|---------|-----------|
| VPC + subnets + SGs | Network isolation | ✓ Free |
| RDS PostgreSQL db.t3.micro + pgvector | Alert/finding store + vector search | ✓ 750hrs/month |
| EC2 t2.micro | FastAPI app server | ✓ 750hrs/month |
| IAM roles + policies | Least-privilege access for collectors | ✓ Free |
| Bedrock model access | Claude Sonnet + Titan Embeddings | Pay per token (~$2/month demo usage) |
| S3 bucket | Terraform state + collector output cache | ✓ 5GB free |

---

## Architecture

```
                    ┌─────────────────────────────────┐
                    │           VPC (10.0.0.0/16)      │
                    │                                   │
                    │  ┌──────────┐  ┌──────────────┐  │
Internet ──────────►│  │ Public   │  │  Private     │  │
                    │  │ Subnet   │  │  Subnet      │  │
                    │  │          │  │              │  │
                    │  │ EC2      │  │ RDS Postgres │  │
                    │  │ t2.micro │──► + pgvector   │  │
                    │  │ FastAPI  │  │              │  │
                    │  └────┬─────┘  └──────────────┘  │
                    └───────┼─────────────────────────--┘
                            │
                    ┌───────▼──────┐
                    │ AWS Services │
                    │ IAM, S3,     │
                    │ GuardDuty,   │
                    │ Cost Explorer│
                    │ CloudTrail   │
                    └───────┬──────┘
                            │
                    ┌───────▼──────┐
                    │ AWS Bedrock  │
                    │ Claude Sonnet│
                    │ Titan Embed  │
                    └──────────────┘
```

---

## Prerequisites

1. AWS CLI configured: `aws configure`
2. Terraform >= 1.5: `brew install terraform`
3. AWS account with Bedrock model access enabled (see below)
4. Free tier account recommended — estimated cost < $5/month

### Enable Bedrock model access

AWS Console → Bedrock → Model access → Request access for:
- `Claude 3 Sonnet` (`anthropic.claude-3-sonnet-20240229-v1:0`)
- `Titan Embeddings V2` (`amazon.titan-embed-text-v2:0`)

Takes 2–5 minutes. Required before `terraform apply`.

---

## Quick start

```bash
# Clone
git clone https://github.com/IshwaryaLakshmiC/aws-governance-copilot-infra
cd aws-governance-copilot-infra

# Configure your values
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
cd environments/dev
terraform init
terraform plan
terraform apply

# Get outputs
terraform output
```

---

## Module structure

```
modules/
  vpc/        — VPC, subnets, internet gateway, route tables, security groups
  rds/        — PostgreSQL RDS + pgvector extension setup
  ec2/        — App server, key pair, elastic IP
  iam/        — Collector roles, Bedrock access policy, instance profile
  bedrock/    — Bedrock invocation policy, model validation
environments/
  dev/        — Dev environment wiring all modules together
scripts/
  init-db.sh  — Installs pgvector extension after RDS is up
  bootstrap.sh — Full setup script: terraform apply + DB init + app deploy
```

---

## After `terraform apply`

1. Run `scripts/init-db.sh` to install pgvector on RDS
2. Note the EC2 public IP from `terraform output`
3. SSH in and deploy the [aws-governance-copilot](https://github.com/IshwaryaLakshmiC/aws-governance-copilot) app
4. Access the copilot at `http://<EC2_PUBLIC_IP>:8000`

---

## Destroying resources

```bash
cd environments/dev
terraform destroy
```

All resources are tagged `project=aws-governance-copilot` for easy identification.

---

**Ishwarya Lakshmi C** — Senior DevOps & Cloud Security Engineer  
[GitHub](https://github.com/IshwaryaLakshmiC) · [Website](https://ishwaryaaunfiltered.live) · [LinkedIn](https://linkedin.com/in/ishwaryachengalvarayan)
