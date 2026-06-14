output "key_arn" {
  description = "ARN of the KMS key."
  value       = module.kms.key_arn
}

output "alias_name" {
  description = "Fully-qualified alias name."
  value       = module.kms.alias_name
}
