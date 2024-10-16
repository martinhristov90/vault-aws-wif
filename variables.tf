variable "public_oidc_issuer_url" {
  type        = string
  description = "Publicly available URL of Vault or an external proxy that serves the OIDC discovery document."
  default     = "https://vault-plugin-wif.mhristov.sbx.hashidemos.io"

  validation {
    condition     = startswith(var.public_oidc_issuer_url, "https://")
    error_message = "The 'public_oidc_issuer_url' must start with https://, e.g. 'https://vault.foo.com'."
  }
}

variable "aws_audience" {
  type        = string
  default     = "sts.amazonaws.com"
  description = "List of audiences (aud) that identify the intended recipients of the token."
}

variable "vault_addr" {
  default = "https://marti.ngrok.io"
}
variable "vault_namespace" {
  #empty means that the AWS auth is in root namespace
  default = ""
}

#Used to determine the publicly accessible address
#For example vault-plugin-wif.mhristov.sbx.hashidemos.io
variable "hosted_zone" {
  default = "mhristov.sbx.hashidemos.io"
}
