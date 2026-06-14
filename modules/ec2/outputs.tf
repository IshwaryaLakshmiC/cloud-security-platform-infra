output "instance_id" { value = aws_instance.app.id }
output "public_ip" { value = aws_eip.app.public_ip }
output "public_dns" { value = aws_eip.app.public_dns }
output "ssh_command" { value = "ssh -i ~/.ssh/${var.project}-key.pem ec2-user@${aws_eip.app.public_ip}" }
