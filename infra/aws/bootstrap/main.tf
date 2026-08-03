data "aws_caller_identity" "current" {}

locals {
  project        = "kube-aegis-forge"
  bucket_name    = "${var.state_bucket_prefix}-${data.aws_caller_identity.current.account_id}-${var.region}"
  state_key      = "eks/kube-aegis-forge.tfstate"
  state_lock_key = "${local.state_key}.tflock"
  infrastructure_read_actions = [
    "ec2:DescribeAccountAttributes",
    "ec2:DescribeAddresses",
    "ec2:DescribeAvailabilityZones",
    "ec2:DescribeFlowLogs",
    "ec2:DescribeImages",
    "ec2:DescribeInstances",
    "ec2:DescribeInternetGateways",
    "ec2:DescribeLaunchTemplates",
    "ec2:DescribeLaunchTemplateVersions",
    "ec2:DescribeNatGateways",
    "ec2:DescribeNetworkAcls",
    "ec2:DescribeNetworkInterfaces",
    "ec2:DescribeRouteTables",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeSecurityGroupRules",
    "ec2:DescribeSubnets",
    "ec2:DescribeTags",
    "ec2:DescribeVpcs",
    "ec2:DescribeVpcAttribute",
    "eks:DescribeAccessEntry",
    "eks:DescribeAddon",
    "eks:DescribeCluster",
    "eks:DescribeNodegroup",
    "eks:ListAccessEntries",
    "eks:ListAddons",
    "eks:ListAssociatedAccessPolicies",
    "eks:ListClusters",
    "eks:ListNodegroups",
    "eks:ListTagsForResource",
    "kms:DescribeKey",
    "kms:GetKeyPolicy",
    "kms:GetKeyRotationStatus",
    "kms:ListAliases",
    "kms:ListResourceTags",
    "logs:DescribeLogGroups",
    "logs:ListTagsForResource",
    "ssm:GetParameter",
    "tag:GetResources"
  ]
  infrastructure_write_actions = concat(local.infrastructure_read_actions, [
    "ec2:AllocateAddress",
    "ec2:AssociateRouteTable",
    "ec2:AttachInternetGateway",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:CreateFlowLogs",
    "ec2:CreateInternetGateway",
    "ec2:CreateLaunchTemplate",
    "ec2:CreateLaunchTemplateVersion",
    "ec2:CreateNatGateway",
    "ec2:CreateNetworkAcl",
    "ec2:CreateNetworkAclEntry",
    "ec2:CreateRoute",
    "ec2:CreateRouteTable",
    "ec2:CreateSecurityGroup",
    "ec2:CreateSubnet",
    "ec2:CreateTags",
    "ec2:CreateVpc",
    "ec2:DeleteFlowLogs",
    "ec2:DeleteInternetGateway",
    "ec2:DeleteLaunchTemplate",
    "ec2:DeleteNatGateway",
    "ec2:DeleteNetworkAcl",
    "ec2:DeleteNetworkAclEntry",
    "ec2:DeleteRoute",
    "ec2:DeleteRouteTable",
    "ec2:DeleteSecurityGroup",
    "ec2:DeleteSubnet",
    "ec2:DeleteTags",
    "ec2:DeleteVpc",
    "ec2:DetachInternetGateway",
    "ec2:DisassociateAddress",
    "ec2:DisassociateRouteTable",
    "ec2:ModifyLaunchTemplate",
    "ec2:ModifySubnetAttribute",
    "ec2:ModifyVpcAttribute",
    "ec2:ReleaseAddress",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "eks:AssociateAccessPolicy",
    "eks:CreateAccessEntry",
    "eks:CreateAddon",
    "eks:CreateCluster",
    "eks:CreateNodegroup",
    "eks:DeleteAccessEntry",
    "eks:DeleteAddon",
    "eks:DeleteCluster",
    "eks:DeleteNodegroup",
    "eks:DisassociateAccessPolicy",
    "eks:TagResource",
    "eks:UntagResource",
    "eks:UpdateAddon",
    "eks:UpdateClusterConfig",
    "eks:UpdateClusterVersion",
    "eks:UpdateNodegroupConfig",
    "eks:UpdateNodegroupVersion",
    "kms:CreateAlias",
    "kms:CreateGrant",
    "kms:CreateKey",
    "kms:DeleteAlias",
    "kms:DisableKey",
    "kms:EnableKey",
    "kms:EnableKeyRotation",
    "kms:PutKeyPolicy",
    "kms:ScheduleKeyDeletion",
    "kms:TagResource",
    "kms:UntagResource",
    "logs:CreateLogGroup",
    "logs:DeleteLogGroup",
    "logs:PutRetentionPolicy",
    "logs:TagResource",
    "logs:UntagResource"
  ])
  managed_policy_read_actions = [
    "iam:GetPolicy",
    "iam:GetPolicyVersion",
    "iam:ListEntitiesForPolicy",
    "iam:ListPolicyTags",
    "iam:ListPolicyVersions"
  ]
  managed_policy_write_actions = concat(local.managed_policy_read_actions, [
    "iam:CreatePolicy",
    "iam:CreatePolicyVersion",
    "iam:DeletePolicy",
    "iam:DeletePolicyVersion",
    "iam:SetDefaultPolicyVersion",
    "iam:TagPolicy",
    "iam:UntagPolicy"
  ])
  tags = {
    Project          = local.project
    ManagedBy        = "OpenTofu"
    CostCenter       = "portfolio"
    ExpirationPolicy = "retain-bootstrap-state"
  }
}

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_key" "state" {
  description             = "Encrypts the Kube Aegis Forge OpenTofu state bucket."
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "state" {
  name          = "alias/${local.project}-state"
  target_key_id = aws_kms_key.state.key_id
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.repository}:environment:aws"]
    }
  }
}

data "aws_iam_policy_document" "github_apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.repository}:environment:aws-apply"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "${local.project}-github-plan"
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_plan_infrastructure" {
  statement {
    sid       = "ReadProjectInfrastructure"
    actions   = local.infrastructure_read_actions
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid = "ReadProjectIam"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project}*"
    ]
  }

  statement {
    sid       = "ReadProjectManagedPolicies"
    actions   = local.managed_policy_read_actions
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.project}*"]
  }
}

resource "aws_iam_role_policy" "github_plan_infrastructure" {
  name   = "regional-infrastructure-read"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_infrastructure.json
}

data "aws_iam_policy_document" "github_plan_state" {
  statement {
    sid     = "ListStateBucket"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.state.arn
    ]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["eks/*"]
    }
  }

  statement {
    sid = "UseStateEncryptionKey"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]
    resources = [aws_kms_key.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_key}"]
  }

  statement {
    sid = "ManageNativeLockOnly"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_lock_key}"]
  }
}

resource "aws_iam_role_policy" "github_plan_state" {
  name   = "state-lock-access"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_state.json
}

resource "aws_iam_role" "github_apply" {
  name                 = "${local.project}-github-apply"
  assume_role_policy   = data.aws_iam_policy_document.github_apply_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_apply_infrastructure" {
  statement {
    sid       = "ManageRegionalProjectInfrastructure"
    actions   = local.infrastructure_write_actions
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }
}

resource "aws_iam_role_policy" "github_apply_infrastructure" {
  name   = "regional-infrastructure-management"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.github_apply_infrastructure.json
}

data "aws_iam_policy_document" "github_apply_state" {
  source_policy_documents = [data.aws_iam_policy_document.github_plan_state.json]

  statement {
    sid = "WriteState"
    actions = [
      "s3:DeleteObject",
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_key}"]
  }
}

resource "aws_iam_role_policy" "github_apply_state" {
  name   = "state-lock-access"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.github_apply_state.json
}

data "aws_iam_policy_document" "github_apply_iam" {
  statement {
    sid = "ManageProjectRoles"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project}*"
    ]
  }

  statement {
    sid       = "ManageProjectManagedPolicies"
    actions   = local.managed_policy_write_actions
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.project}*"]
  }

  statement {
    sid       = "CreateRequiredServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "autoscaling.amazonaws.com",
        "eks.amazonaws.com",
        "elasticloadbalancing.amazonaws.com"
      ]
    }
  }

  statement {
    sid       = "ProtectBootstrapStateBucket"
    effect    = "Deny"
    actions   = ["s3:DeleteBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
}

resource "aws_iam_role_policy" "github_apply_iam" {
  name   = "project-iam-and-state-protection"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.github_apply_iam.json
}

