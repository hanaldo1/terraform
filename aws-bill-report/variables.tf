variable "aws_account" {
  default = ""
}

variable "slack_bot_token" {
  default = ""
  sensitive = true
}

variable "slack_channel" {
  default = ""
}