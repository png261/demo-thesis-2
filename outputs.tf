output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.app_server.id
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance."
  value       = aws_instance.app_server.private_ip
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}
