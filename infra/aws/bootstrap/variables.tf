variable "region" {
  description = "AWS region for the state bucket and IAM bootstrap."
  type        = string
  default     = "eu-west-3"
}

variable "repository" {
  description = "GitHub owner/repository allowed to request AWS credentials."
  type        = string
  default     = "murillo-consulting/kube-aegis-forge"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository))
    error_message = "repository must use the owner/name form."
  }
}

variable "state_bucket_prefix" {
  description = "Prefix for the globally unique state bucket."
  type        = string
  default     = "kube-aegis-forge-state"
}

