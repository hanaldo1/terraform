variable "server_port" {
  default = 51820
}

variable "server_network" {
  default = "10.100.100"
}

variable "ui_port" {
  default = 51821
}

variable "ui_password" {
  type = string
  sensitive = true
}

variable "ui_traffic_stats" {
  default = true
}

variable "ui_chart_type" {
  default = "1"
}

variable "public_access_allowed_ips" {
  default = []
}