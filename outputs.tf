output "api_url" {
  description = "Publiczny adres URL do wysyłania zamówień"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/orders"
}

output "ingest_function_arn" {
  description = "ARN funkcji pobrany z modułu"
  value       = module.order_ingest.function_arn
}