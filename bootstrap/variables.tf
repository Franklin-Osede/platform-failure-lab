variable "region" {
  description = "AWS region for the state bucket. Use the same region as the lab infra."
  type        = string
  default     = "eu-west-1"
}

variable "force_destroy" {
  description = "Allow destroying the bucket with all state versions inside. Only set true when tearing the whole lab down."
  type        = bool
  default     = false
}

variable "noncurrent_version_days" {
  description = "Days to keep old state versions (your recovery window for scenario 03)."
  type        = number
  default     = 90
}
