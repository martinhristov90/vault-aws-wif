provider "aws" {
}

locals {
  oidc_issuer_without_https = replace(var.public_oidc_issuer_url, "https://", "")
}

data "aws_caller_identity" "current" {
}

#TLS certificate servered by the API gataway
data "tls_certificate" "vault_oidc_issuer_certificate" {
  url          = var.public_oidc_issuer_url
  verify_chain = false
  depends_on = [
    // need to wait for the validation to finish before we can use the domain, and the A record to be created
    aws_acm_certificate_validation.example,
    aws_route53_record.domain
  ]
}

#Creating a OIDC provider, in this case it is Vault itself
resource "aws_iam_openid_connect_provider" "vault_plugin_wif_provider" {
  url            = "${var.public_oidc_issuer_url}/v1/identity/oidc/plugins"
  client_id_list = [var.aws_audience]
  #getting the thumbprint from the certificate of the OIDC provider (the CA of it) (the publicly accessible proxy to be exact)
  thumbprint_list = [data.tls_certificate.vault_oidc_issuer_certificate.certificates[0].sha1_fingerprint]
}

#The Vault role assumed by Vault server, it will be assumed via AssumeRoleWithWebIdentity
#vault_auth_backend.aws.accessor will be the accessor of AWS auth method
resource "aws_iam_role" "vault_plugin_wif_role" {
  name = "vault-plugin-wif-role"
  path = "/vault/"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${aws_iam_openid_connect_provider.vault_plugin_wif_provider.arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${local.oidc_issuer_without_https}/v1/identity/oidc/plugins:sub" : "plugin-identity:root:auth:${vault_auth_backend.aws.accessor}",
            "${local.oidc_issuer_without_https}/v1/identity/oidc/plugins:aud" : "${var.aws_audience}"
          }
        }
      },
    ]
  })
}


#AWS IAM policy which allows AWS auth method to function properly
resource "aws_iam_policy" "vault_plugin_wif_policy" {
  name        = "vault-plugin-wif-policy"
  description = "Vault Plugin WIF policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeInstances",
          "iam:GetInstanceProfile",
          "iam:GetUser",
          "iam:GetRole"
        ],
        "Resource" : "*"
      },
      # {
      #   "Effect" : "Allow",
      #   "Action" : [
      #     "sts:AssumeRole",
      #   ],
      #   "Resource" : "arn:aws:iam::${data.aws_caller_identity.target_account.account_id}:role/*"
      # }
    ]
  })
}

#Attaching the policy to the role
resource "aws_iam_role_policy_attachment" "vault_plugin_wif_policy_attachment" {
  role       = aws_iam_role.vault_plugin_wif_role.name
  policy_arn = aws_iam_policy.vault_plugin_wif_policy.arn
}