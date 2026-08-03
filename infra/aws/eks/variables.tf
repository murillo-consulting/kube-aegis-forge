variable "region" {
  description = "AWS region for the optional EKS deployment."
  type        = string
  default     = "eu-west-3"

  validation {
    condition     = var.region == "eu-west-3"
    error_message = "The v1 reference architecture is intentionally fixed to eu-west-3."
  }
}

variable "admin_cidrs" {
  description = "Non-empty, narrow CIDR allowlist for the public EKS API endpoint. IPv4 prefixes must be /24 or narrower; IPv6 prefixes must be /64 or narrower."
  type        = list(string)

  validation {
    condition = length(var.admin_cidrs) > 0 && alltrue([
      for cidr in var.admin_cidrs : can(cidrhost(cidr, 0)) && can(
        strcontains(cidr, ":")
        ? tonumber(split("/", cidr)[1]) >= 64
        : tonumber(split("/", cidr)[1]) >= 24
      )
    ])
    error_message = "admin_cidrs must contain valid IPv4 /24-or-narrower or IPv6 /64-or-narrower CIDRs."
  }
}

variable "cluster_admin_role_arn" {
  description = "Existing IAM role granted explicit EKS cluster-admin access through an access entry."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.cluster_admin_role_arn))
    error_message = "cluster_admin_role_arn must be a valid IAM role ARN in the aws partition."
  }
}

variable "node_instance_types" {
  description = "EC2 types allowed for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]

  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "At least one node instance type is required."
  }
}

variable "node_min_size" {
  description = "Minimum managed node count."
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired managed node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum managed node count."
  type        = number
  default     = 3
}

variable "vpc_cidr" {
  description = "CIDR for the demonstration VPC."
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR."
  }
}
