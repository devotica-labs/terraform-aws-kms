output "key_arn" {
  description = "ARN of the KMS key."
  value       = module.kms.key_arn
}

output "key_id" {
  description = "ID of the KMS key."
  value       = module.kms.key_id
}

output "alias_name" {
  description = "Fully-qualified alias name."
  value       = module.kms.alias_name
}

output "alias_arn" {
  description = "ARN of the KMS alias."
  value       = module.kms.alias_arn
}

output "key_rotation_enabled" {
  description = "Whether automatic annual key-material rotation is on."
  value       = module.kms.key_rotation_enabled
}

output "multi_region" {
  description = "Whether this key was created as a multi-region primary."
  value       = module.kms.multi_region
}
