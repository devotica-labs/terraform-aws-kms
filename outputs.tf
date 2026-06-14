output "key_arn" {
  description = "ARN of the KMS key."
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "ID of the KMS key."
  value       = aws_kms_key.this.id
}

output "alias_arn" {
  description = "ARN of the KMS alias."
  value       = aws_kms_alias.this.arn
}

output "alias_name" {
  description = "Fully-qualified alias name (with the leading \"alias/\" prefix)."
  value       = aws_kms_alias.this.name
}

output "key_rotation_enabled" {
  description = "Whether automatic annual key-material rotation is on. Always false for non-symmetric keys (AWS does not support rotation on those)."
  value       = aws_kms_key.this.enable_key_rotation
}

output "multi_region" {
  description = "Whether this key was created as a multi-region primary."
  value       = aws_kms_key.this.multi_region
}
