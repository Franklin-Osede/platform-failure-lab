output "instance_id" {
  value = aws_instance.lab.id
}

output "security_group_id" {
  value = aws_security_group.lab.id
}
