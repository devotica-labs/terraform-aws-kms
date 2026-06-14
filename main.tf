# ---------------------------------------------------------------------------
# KMS key — fintech-grade defaults:
#   - Annual key-material rotation on
#   - Deletion window 30 days
#   - Symmetric encrypt/decrypt
#   - Multi-region opt-in
# ---------------------------------------------------------------------------

resource "aws_kms_key" "this" {
  description              = var.description
  key_usage                = var.key_usage
  customer_master_key_spec = var.customer_master_key_spec
  enable_key_rotation      = var.enable_key_rotation && var.key_usage == "ENCRYPT_DECRYPT" && var.customer_master_key_spec == "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = var.deletion_window_in_days
  multi_region             = var.multi_region
  policy                   = data.aws_iam_policy_document.key.json

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Alias — globally unique within the account/region.
# ---------------------------------------------------------------------------

resource "aws_kms_alias" "this" {
  name          = local.alias_full
  target_key_id = aws_kms_key.this.id
}
