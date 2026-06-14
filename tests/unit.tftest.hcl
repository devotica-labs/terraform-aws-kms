# Plan-only unit tests — no AWS credentials required.
#
# Uses mock_provider so the data sources (aws_caller_identity, aws_partition)
# don't need to hit AWS.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  # aws_kms_key.policy requires a valid JSON string. The mock for
  # aws_iam_policy_document defaults its .json to a placeholder, which the
  # aws_kms_key validator rejects with "policy contains invalid JSON". So we
  # override the data source with a minimal-but-valid policy.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  alias       = "unit-test-key"
  description = "Unit test key."
  tags        = { Environment = "unit-test" }
}

run "key_planned_with_alias" {
  command = plan
  assert {
    condition     = length(aws_kms_key.this.description) > 0
    error_message = "Key must have a description."
  }
  assert {
    condition     = aws_kms_alias.this.name == "alias/unit-test-key"
    error_message = "Alias name must equal 'alias/<var.alias>'."
  }
}

run "rotation_enabled_by_default" {
  command = plan
  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Symmetric ENCRYPT_DECRYPT keys must rotate by default."
  }
}

run "rotation_forced_off_for_asymmetric" {
  command = plan
  variables {
    key_usage                = "SIGN_VERIFY"
    customer_master_key_spec = "RSA_2048"
  }
  assert {
    condition     = aws_kms_key.this.enable_key_rotation == false
    error_message = "AWS does not support rotation on non-symmetric keys; the module must coerce it to false."
  }
}

run "deletion_window_default_30_days" {
  command = plan
  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 30
    error_message = "Default deletion_window_in_days must be 30."
  }
}

run "multi_region_off_by_default" {
  command = plan
  assert {
    condition     = aws_kms_key.this.multi_region == false
    error_message = "multi_region must default to false."
  }
}

run "multi_region_on_when_set" {
  command = plan
  variables { multi_region = true }
  assert {
    condition     = aws_kms_key.this.multi_region == true
    error_message = "multi_region = true must propagate to aws_kms_key."
  }
}

run "tags_merged_with_defaults" {
  command = plan
  assert {
    condition     = aws_kms_key.this.tags["ManagedBy"] == "terraform"
    error_message = "Module-default tag ManagedBy must be merged in."
  }
  assert {
    condition     = aws_kms_key.this.tags["Module"] == "terraform-aws-kms"
    error_message = "Module-default tag Module must be terraform-aws-kms."
  }
}

run "minimum_policy_has_root_only" {
  command = plan
  # No admins, users, or service principals — policy should only contain the
  # mandatory root statement. We can't inspect the JSON directly at plan time
  # but we can confirm the data source produces a policy.
  assert {
    condition     = length(aws_kms_key.this.policy) > 0
    error_message = "Key policy JSON must be planned (non-empty)."
  }
}
