mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/opentofu-test"
      user_id    = "AIDAEXAMPLE"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition          = "aws"
      dns_suffix         = "amazonaws.com"
      reverse_dns_prefix = "com.amazonaws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      minified_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:user/opentofu-test"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/kube-aegis-forge-test"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/kube-aegis-forge-test"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-west-3:123456789012:log-group:/aws/vpc-flow-log/kube-aegis-forge"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      arn      = "arn:aws:eks:eu-west-3:123456789012:cluster/kube-aegis-forge"
      endpoint = "https://example.invalid"
      certificate_authority = [{
        data = "dGVzdA=="
      }]
      identity = [{
        oidc = [{
          issuer = "https://oidc.eks.eu-west-3.amazonaws.com/id/example"
        }]
      }]
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id = "lt-0123456789abcdef0"
    }
  }
}

run "secure_defaults" {
  command = plan

  variables {
    admin_cidrs            = ["203.0.113.10/32"]
    cluster_admin_role_arn = "arn:aws:iam::123456789012:role/kube-aegis-forge-admin"
  }

  assert {
    condition     = var.region == "eu-west-3"
    error_message = "The reference region changed unexpectedly."
  }

  assert {
    condition     = var.node_min_size == 1 && var.node_desired_size == 2 && var.node_max_size == 3
    error_message = "Managed node scaling defaults changed unexpectedly."
  }

  assert {
    condition = (
      output.security_baseline.cluster_creator_admin == false &&
      output.security_baseline.irsa_enabled == false &&
      output.security_baseline.imdsv2 == "required" &&
      output.security_baseline.vpc_flow_logs == true &&
      output.security_baseline.vpc_flow_log_iam_name == "kube-aegis-forge-vpc-flow-logs"
    )
    error_message = "The explicit EKS, identity, IMDSv2, or VPC Flow Logs baseline changed unexpectedly."
  }

  assert {
    condition     = length(output.security_baseline.control_plane_logs) == 5
    error_message = "Every EKS control-plane log type must remain enabled."
  }
}

run "ipv6_admin_cidr" {
  command = plan

  variables {
    admin_cidrs            = ["2001:db8::/64"]
    cluster_admin_role_arn = "arn:aws:iam::123456789012:role/platform-admin"
  }

  assert {
    condition     = var.admin_cidrs == ["2001:db8::/64"]
    error_message = "A narrow IPv6 API allowlist must pass validation."
  }
}
