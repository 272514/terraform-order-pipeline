variable "function_name" {
  type        = string
  description = "Nazwa funkcji Lambda"
}

variable "handler" {
  type        = string
  description = "Punkt wejsciowy funkcji"
}

variable "runtime" {
  type        = string
  description = "Srodowisko (np. python3.11)"
}

variable "role_arn" {
  type        = string
  description = "ARN roli IAM"
}

variable "source_dir" {
  type        = string
  description = "Sciezka do kodu zrodlowego Lambdy"
}

variable "environment_vars" {
  type        = map(string)
  default     = {}
  description = "Zmienne srodowiskowe"
}