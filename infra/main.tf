# Deliberately minimal infrastructure: one EC2 instance, one security group,
# tags. Small enough that every symptom in a scenario has an obvious cause.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "platform-failure-lab"
      ManagedBy = "terraform"
      Lab       = "01-terraform-state"
    }
  }
}

# Uses the account's default VPC to avoid paying for NAT or building a network.
# Prerequisite: the default VPC must exist in var.region.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# No inline ingress/egress blocks on purpose: rules are separate resources.
# Scenario 02 relies on this — a rule added by hand is NOT managed by any
# resource here, which changes how (and whether) Terraform reports it.
resource "aws_security_group" "lab" {
  name_prefix = "pfl-lab-"
  description = "Platform Failure Lab instance - no inbound access"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "pfl-lab"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.lab.id
  description       = "HTTPS out"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_instance" "lab" {
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.lab.id]
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name  = "pfl-lab"
    Owner = var.owner # scenario 02 changes this tag outside Terraform
  }
}

# Only exists while a scenario needs a slow apply (scenario 01 and the
# locking exercise in 00). With the default slow_apply_seconds = 0 it is absent.
resource "time_sleep" "slow" {
  count = var.slow_apply_seconds > 0 ? 1 : 0

  create_duration = "${var.slow_apply_seconds}s"

  triggers = {
    run_id = var.run_id
  }
}
