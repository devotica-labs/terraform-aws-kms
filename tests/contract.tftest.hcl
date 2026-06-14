# Contract tests — output surface stays stable across minor + patch versions.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  alias = "contract-test-key"
}

run "key_resource_planned" {
  command = plan
  assert {
    condition     = length([aws_kms_key.this]) == 1
    error_message = "Exactly one aws_kms_key.this resource must be planned."
  }
}

run "alias_resource_planned" {
  command = plan
  assert {
    condition     = length([aws_kms_alias.this]) == 1
    error_message = "Exactly one aws_kms_alias.this resource must be planned."
  }
  assert {
    condition     = aws_kms_alias.this.name == "alias/contract-test-key"
    error_message = "alias_full local must produce 'alias/<var.alias>'."
  }
}

run "policy_always_present" {
  command = plan
  assert {
    condition     = length(aws_kms_key.this.policy) > 0
    error_message = "Key policy must always be set — never null/empty."
  }
}

run "key_usage_defaults_to_encrypt_decrypt" {
  command = plan
  assert {
    condition     = aws_kms_key.this.key_usage == "ENCRYPT_DECRYPT"
    error_message = "Default key_usage must remain ENCRYPT_DECRYPT (covers SSE-KMS for S3/EBS/RDS/Logs)."
  }
}

run "customer_master_key_spec_defaults_to_symmetric" {
  command = plan
  assert {
    condition     = aws_kms_key.this.customer_master_key_spec == "SYMMETRIC_DEFAULT"
    error_message = "Default customer_master_key_spec must remain SYMMETRIC_DEFAULT."
  }
}
