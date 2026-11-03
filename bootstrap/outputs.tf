output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "region" {
  value = var.region
}

# Written to infra/backend.hcl by `make bootstrap`.
output "backend_hcl" {
  value = <<-EOT
    bucket = "${aws_s3_bucket.state.bucket}"
    region = "${var.region}"
  EOT
}
