# ---------------------------------------------------------------------------
# Core identity
# ---------------------------------------------------------------------------

variable "account_id" {
  description = "AWS account ID baked into the mandatory root statement of the key policy. Leave empty to auto-detect via the aws_caller_identity data source (needs live STS creds at plan time). Set explicitly for offline plan workflows (CI examples-build, architecture-diagram render) where STS isn't reachable."
  type        = string
  default     = ""
  validation {
    condition     = var.account_id == "" || can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID or empty (auto-detect)."
  }
}

variable "alias" {
  description = "Alias for the KMS key (without the `alias/` prefix — the module adds it). E.g. \"devotica-app-data\"."
  type        = string
  validation {
    condition     = length(var.alias) >= 1 && length(var.alias) <= 256 && can(regex("^[a-zA-Z0-9/_-]+$", var.alias))
    error_message = "alias must be 1–256 chars: letters, digits, /, _, - only. Do NOT include the leading 'alias/' prefix."
  }
}

variable "description" {
  description = "Free-text description for the key (max 8192 chars)."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Key spec — defaults are the fintech-safe pick (symmetric, encrypt-decrypt).
# ---------------------------------------------------------------------------

variable "key_usage" {
  description = "Cryptographic operations the key supports. ENCRYPT_DECRYPT covers SSE-KMS for S3/EBS/RDS/Logs; SIGN_VERIFY is for digital signatures."
  type        = string
  default     = "ENCRYPT_DECRYPT"
  validation {
    condition     = contains(["ENCRYPT_DECRYPT", "SIGN_VERIFY", "GENERATE_VERIFY_MAC"], var.key_usage)
    error_message = "key_usage must be ENCRYPT_DECRYPT, SIGN_VERIFY, or GENERATE_VERIFY_MAC."
  }
}

variable "customer_master_key_spec" {
  description = "Cryptographic key material spec. SYMMETRIC_DEFAULT is the right answer for almost every SSE-KMS use case; the asymmetric specs are for digital signatures or key wrapping."
  type        = string
  default     = "SYMMETRIC_DEFAULT"
  validation {
    condition = contains(
      ["SYMMETRIC_DEFAULT", "RSA_2048", "RSA_3072", "RSA_4096",
        "ECC_NIST_P256", "ECC_NIST_P384", "ECC_NIST_P521", "ECC_SECG_P256K1",
      "HMAC_224", "HMAC_256", "HMAC_384", "HMAC_512", "SM2"],
      var.customer_master_key_spec
    )
    error_message = "customer_master_key_spec must be a valid AWS-supported spec."
  }
}

# ---------------------------------------------------------------------------
# Rotation
# ---------------------------------------------------------------------------

variable "enable_key_rotation" {
  description = "Enable automatic annual key-material rotation. AWS rotates the backing key while the key ID stays the same. Required for CIS AWS Foundations 3.8 and RBI cyber-security guidance on key lifecycle."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Deletion
# ---------------------------------------------------------------------------

variable "deletion_window_in_days" {
  description = "Days the key sits in PendingDeletion before AWS irreversibly deletes it. 7 minimum, 30 default (AWS recommends 30 for production)."
  type        = number
  default     = 30
  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

# ---------------------------------------------------------------------------
# Multi-region — opt-in. Needed for cross-region DR (RBI data durability).
# ---------------------------------------------------------------------------

variable "multi_region" {
  description = "Create the key as a multi-region primary. Set true if you plan to replicate it to a DR region via a separate replica resource. Cannot be changed after key creation."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Key policy — built from feature flags rather than a raw JSON blob.
#
# All three lists below default to empty. The module always grants the AWS
# account root full kms:* (required by AWS — without it the key is bricked
# and cannot be recovered). Everything beyond that is opt-in.
# ---------------------------------------------------------------------------

variable "key_administrators" {
  description = "List of IAM principal ARNs allowed to administer the key (manage policy, schedule deletion, enable/disable rotation) but NOT use it for cryptographic operations."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for arn in var.key_administrators : can(regex("^arn:aws:iam::", arn))])
    error_message = "key_administrators must be IAM principal ARNs (arn:aws:iam::...)."
  }
}

variable "key_users" {
  description = "List of IAM principal ARNs allowed to perform cryptographic operations (Encrypt, Decrypt, ReEncrypt*, GenerateDataKey*, DescribeKey) using the key."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for arn in var.key_users : can(regex("^arn:aws:iam::", arn))])
    error_message = "key_users must be IAM principal ARNs (arn:aws:iam::...)."
  }
}

variable "service_principals" {
  description = "List of AWS service principal names that can use the key via the corresponding service. E.g. [\"logs.ap-south-1.amazonaws.com\"] for a CloudWatch Log Group, [\"s3.amazonaws.com\"] for an S3 bucket. Constrained by a kms:ViaService condition."
  type        = list(string)
  default     = []
}

variable "additional_policy_statements" {
  description = "Escape hatch — list of additional IAM policy statement objects merged into the key policy. Use when you need a permission shape the variables above don't cover."
  type = list(object({
    sid           = optional(string)
    effect        = optional(string, "Allow")
    actions       = list(string)
    not_actions   = optional(list(string), [])
    resources     = optional(list(string), ["*"])
    not_resources = optional(list(string), [])
    principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })), [])
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags merged onto every taggable resource (the key and the alias)."
  type        = map(string)
  default     = {}
}
