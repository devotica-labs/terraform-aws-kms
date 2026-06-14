data "aws_caller_identity" "current" {
  # Only call STS when the caller didn't pass an explicit account_id. Lets
  # offline plan workflows (CI examples-build, architecture-diagram render)
  # skip the STS call by setting var.account_id directly.
  count = var.account_id == "" ? 1 : 0
}

data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# Key policy — built from feature flags via aws_iam_policy_document.
#
# Statement order:
#   1. Root account — full kms:*. Required by AWS to prevent the key being
#      orphaned. Always present.
#   2. Key administrators — manage-only actions.
#   3. Key users — crypto-op actions.
#   4. Service principals — crypto-op actions gated by kms:ViaService.
#   5. Any additional_policy_statements the caller passes through.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "key" {
  # 1. Root — required
  statement {
    sid     = "EnableIAMUserPermissions"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${local.effective_account_id}:root"]
    }
    resources = ["*"]
  }

  # 2. Administrators
  dynamic "statement" {
    for_each = length(var.key_administrators) > 0 ? [1] : []
    content {
      sid       = "AllowKeyAdministration"
      effect    = "Allow"
      actions   = local.admin_actions
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = var.key_administrators
      }
    }
  }

  # 3. Users
  dynamic "statement" {
    for_each = length(var.key_users) > 0 ? [1] : []
    content {
      sid       = "AllowKeyUsage"
      effect    = "Allow"
      actions   = local.user_actions
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = var.key_users
      }
    }
  }

  # 4. Service principals — gated by kms:ViaService for defense-in-depth
  dynamic "statement" {
    for_each = var.service_principals
    content {
      sid       = "AllowService_${replace(statement.value, ".", "_")}"
      effect    = "Allow"
      actions   = local.user_actions
      resources = ["*"]
      principals {
        type        = "Service"
        identifiers = [statement.value]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = [statement.value]
      }
    }
  }

  # 5. Caller escape hatch
  dynamic "statement" {
    for_each = var.additional_policy_statements
    content {
      sid           = statement.value.sid
      effect        = statement.value.effect
      actions       = statement.value.actions
      not_actions   = statement.value.not_actions
      resources     = statement.value.resources
      not_resources = statement.value.not_resources

      dynamic "principals" {
        for_each = statement.value.principals
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}
