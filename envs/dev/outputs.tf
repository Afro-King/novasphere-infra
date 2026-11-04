output "alb_dns_name" {
  description = "Point d'entree unique de l'application (les instances ne sont jamais exposees)"
  value       = aws_lb.web.dns_name
}

output "monitoring_public_ip" {
  description = "Adresse IP publique du serveur de supervision"
  value       = module.monitoring_dev.public_ip
}
