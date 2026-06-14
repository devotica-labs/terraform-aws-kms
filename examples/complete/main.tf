# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/kms/aws"
#   version = "~> 0.1"

module "kms" {
  source = "../.."

  # Hardcoded for offline CI plan (the example skips STS via the provider's
  # skip_* flags). In a real deployment, drop this line and the module will
  # auto-detect via the aws_caller_identity data source.
  account_id = "111122223333"

  alias       = "devotica-app-data"
  description = "Multi-region SSE-KMS key for devotica-app data at rest. Used by S3, RDS, EBS, Secrets Manager."

  # Multi-region for cross-region DR (RBI data-durability mandate).
  multi_region = true

  # ── Administration: dedicated security team role can manage but not use ──
  key_administrators = [
    "arn:aws:iam::111122223333:role/devotica-security-kms-admin",
  ]

  # ── Direct use: the app's task role can encrypt/decrypt ──
  key_users = [
    "arn:aws:iam::111122223333:role/devotica-prod-ecs-task",
    "arn:aws:iam::111122223333:role/devotica-prod-lambda-exec",
  ]

  # ── AWS service principals — usage gated by kms:ViaService ──
  # E.g. CloudWatch Log Groups in this region, S3 buckets at large.
  service_principals = [
    "logs.ap-south-1.amazonaws.com",
    "s3.amazonaws.com",
  ]

  # Defaults already include rotation enabled + 30-day deletion window.

  tags = {
    Environment = "production"
    Project     = "platform"
    Owner       = "cloud-team@devotica.com"
    CostCenter  = "PLATFORM"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-kms"
  }
}
