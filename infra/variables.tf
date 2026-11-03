variable "region" {
  description = "AWS region. Must match the region in backend.hcl."
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "Smallest useful size; the instance runs nothing."
  type        = string
  default     = "t3.micro"
}

variable "owner" {
  description = "Value of the Owner tag on the instance."
  type        = string
  default     = "platform-failure-lab"
}

variable "slow_apply_seconds" {
  description = "When > 0, adds a time_sleep so an apply holds the state lock for this long."
  type        = number
  default     = 0

  validation {
    condition     = var.slow_apply_seconds >= 0 && var.slow_apply_seconds <= 900
    error_message = "slow_apply_seconds must be between 0 and 900."
  }
}

variable "run_id" {
  description = "Change this to force the time_sleep to run again."
  type        = string
  default     = ""
}
