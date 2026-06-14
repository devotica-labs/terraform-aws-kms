locals {
  common_tags = merge(
    { ManagedBy = "terraform", Module = "terraform-aws-kms" },
    var.tags
  )

  # Use var.account_id when provided; otherwise the data source (which is
  # only created when var.account_id is empty).
  effective_account_id = var.account_id != "" ? var.account_id : data.aws_caller_identity.current[0].account_id

  # Alias is stored with the leading "alias/" prefix on the resource but the
  # variable surface accepts the bare name to keep callers honest about it.
  alias_full = "alias/${var.alias}"

  # The key administrator action set — manage but not USE.
  admin_actions = [
    "kms:Create*",
    "kms:Describe*",
    "kms:Enable*",
    "kms:List*",
    "kms:Put*",
    "kms:Update*",
    "kms:Revoke*",
    "kms:Disable*",
    "kms:Get*",
    "kms:Delete*",
    "kms:TagResource",
    "kms:UntagResource",
    "kms:ScheduleKeyDeletion",
    "kms:CancelKeyDeletion",
    "kms:ImportKeyMaterial",
    "kms:GetKeyRotationStatus",
  ]

  # The key user action set — USE the key for crypto ops, no management.
  user_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey",
  ]
}
