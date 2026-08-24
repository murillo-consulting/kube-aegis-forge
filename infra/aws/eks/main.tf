locals {
  name              = "kube-aegis-forge"
  azs               = ["${var.region}a", "${var.region}b"]
  flow_log_iam_name = "${local.name}-vpc-flow-logs"
  irsa_enabled      = false
  control_plane_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  tags = {
    Project          = local.name
    ManagedBy        = "OpenTofu"
    CostCenter       = "portfolio"
    ExpirationPolicy = "review-seven-days-after-creation"
  }
}

check "node_scaling_bounds" {
  assert {
    condition = (
      var.node_min_size >= 1 &&
      var.node_min_size <= var.node_desired_size &&
      var.node_desired_size <= var.node_max_size
    )
    error_message = "Node sizes must satisfy 1 <= min <= desired <= max."
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 8), cidrsubnet(var.vpc_cidr, 4, 9)]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = false

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  vpc_flow_log_iam_role_name                      = local.flow_log_iam_name
  vpc_flow_log_iam_role_use_name_prefix           = false
  vpc_flow_log_iam_policy_name                    = local.flow_log_iam_name
  vpc_flow_log_iam_policy_use_name_prefix         = false
  flow_log_cloudwatch_log_group_retention_in_days = 30
  flow_log_max_aggregation_interval               = 60

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  name               = local.name
  kubernetes_version = "1.36"

  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.admin_cidrs

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  enable_irsa                              = local.irsa_enabled
  enabled_log_types                        = local.control_plane_log_types
  cloudwatch_log_group_retention_in_days   = 30
  encryption_config = {
    resources = ["secrets"]
  }
  enable_kms_key_rotation = true

  access_entries = {
    administrator = {
      principal_arn = var.cluster_admin_role_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  iam_role_name = "${local.name}-cluster"

  eks_managed_node_groups = {
    primary = {
      name           = "${local.name}-primary"
      instance_types = var.node_instance_types
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      iam_role_name = "${local.name}-nodes"
      metadata_options = {
        http_endpoint               = "enabled"
        http_put_response_hop_limit = 1
        http_tokens                 = "required"
      }

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            delete_on_termination = true
            encrypted             = true
            volume_size           = 40
            volume_type           = "gp3"
          }
        }
      }
    }
  }
}

