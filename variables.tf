variable "instance_name" {
  description = "Name tag for the EC2 instance."
  type        = string
  default     = "demo-thesis-2-server"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}
