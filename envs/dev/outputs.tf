output "web_public_ip" {
  description = "Adresse IP publique du serveur web"
  value       = module.web.public_ip
}

output "monitoring_public_ip" {
  description = "Adresse IP publique du serveur de supervision"
  value       = module.monitoring.public_ip
}
