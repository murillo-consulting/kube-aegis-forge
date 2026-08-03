mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/opentofu-test"
      user_id    = "AIDAEXAMPLE"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      minified_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:eu-west-3:123456789012:key/00000000-0000-0000-0000-000000000000"
      key_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/kube-aegis-forge-test"
    }
  }
}

run "security_controls" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.force_destroy == false
    error_message = "The retained state bucket must not use force_destroy."
  }

  assert {
    condition     = aws_kms_key.state.enable_key_rotation == true
    error_message = "State encryption key rotation must remain enabled."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.state.block_public_acls &&
      aws_s3_bucket_public_access_block.state.block_public_policy &&
      aws_s3_bucket_public_access_block.state.ignore_public_acls &&
      aws_s3_bucket_public_access_block.state.restrict_public_buckets
    )
    error_message = "Every S3 public-access block must remain enabled."
  }

  assert {
    condition = (
      aws_iam_role.github_plan.max_session_duration == 3600 &&
      aws_iam_role.github_apply.max_session_duration == 3600
    )
    error_message = "GitHub OIDC sessions must remain short lived."
  }

  assert {
    condition = (
      contains(local.managed_policy_read_actions, "iam:GetPolicyVersion") &&
      contains(local.managed_policy_write_actions, "iam:CreatePolicy") &&
      contains(local.managed_policy_write_actions, "iam:DeletePolicy")
    )
    error_message = "The EKS encryption policy must remain readable by plan and manageable by apply."
  }

  assert {
    condition     = contains(local.infrastructure_read_actions, "ec2:DescribeSecurityGroupRules")
    error_message = "Plan and apply must be able to refresh individual security-group rules."
  }
}
