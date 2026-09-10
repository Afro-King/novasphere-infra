output "public_ip" {
  description = "Adresse IP publique du serveur"
  value       = aws_instance.this.public_ip
}

output "instance_id" {
  description = "Identifiant de l'instance EC2"
  value       = aws_instance.this.id
}

output "security_group_id" {
  description = "Identifiant du Security Group"
  value       = aws_security_group.this.id
}
