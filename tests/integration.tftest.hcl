# Integration tests — apply + assert + destroy.
# Requires real AWS credentials. Triggered via workflow_dispatch on integration.yml.
# Run manually: terraform test -filter=tests/integration.tftest.hcl

provider "aws" {
  region = "ap-south-1"
}

variables {
  alias       = "integ-test-key"
  description = "Integration test key. Ephemeral — destroyed by terraform test."
  tags        = { Environment = "integration-test", Ephemeral = "true" }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_kms_key.this.arn != ""
    error_message = "Key ARN must be set after apply."
  }
  assert {
    condition     = aws_kms_alias.this.name == "alias/integ-test-key"
    error_message = "Alias name must match the configured value."
  }
  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Rotation must be on for the default symmetric key."
  }
  assert {
    condition     = aws_kms_key.this.multi_region == false
    error_message = "multi_region must default to false."
  }
}
