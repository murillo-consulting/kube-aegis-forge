output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "region" {
  description = "AWS region."
  value       = var.region
}

output "configure_kubectl" {
  description = "Command to configure kubectl after apply."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "security_baseline" {
  description = "Non-sensitive controls enabled by the optional AWS reference architecture."
  value = {
    cluster_admin_source  = "explicit EKS access entry"
    cluster_creator_admin = false
    control_plane_logs    = local.control_plane_log_types
    irsa_enabled          = local.irsa_enabled
    imdsv2                = "required"
    secrets_encryption    = "customer-managed KMS key with rotation"
    state_locking         = "native S3 lockfile"
    worker_root_volume    = "encrypted gp3"
    vpc_flow_logs         = true
    vpc_flow_log_iam_name = local.flow_log_iam_name
    workload_nodes        = "private subnets"
  }
}
