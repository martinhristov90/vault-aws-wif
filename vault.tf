#Vault running locally in dev mode
provider "vault" {
  address = "http://127.1:8200"
  token   = "root"
}
resource "vault_identity_oidc" "issuer_url" {
  issuer = var.public_oidc_issuer_url
}

resource "vault_identity_oidc_key" "plugin_wif" {
  name               = "plugin-wif-key"
  rotation_period    = 60 * 60 * 24 * 90 # 90 days
  verification_ttl   = 60 * 60 * 24      # 24 hours
  algorithm          = "RS256"
  allowed_client_ids = [var.aws_audience]
}

resource "vault_auth_backend" "aws" {
  type               = "aws"
  identity_token_key = vault_identity_oidc_key.plugin_wif.id

  tune {
    default_lease_ttl = "30m"
    max_lease_ttl     = "2h"
  }
}

resource "vault_aws_auth_backend_client" "aws" {
  backend                 = vault_auth_backend.aws.path
  identity_token_audience = var.aws_audience #The audience should match with the assumed role, check vault_plugin_wif_role
  role_arn                = aws_iam_role.vault_plugin_wif_role.arn
  identity_token_ttl      = 60 * 5 # 5 minutes
}

# local aws role config (to do)
# role name matches the role of the instance profile of the EC2 instance. No "role=" parameter should be provided via "vault login -method=aws" command.
#resource "vault_aws_auth_backend_role" "aws_iam_type_auth" {
#  backend              = vault_auth_backend.aws.path
#  role                 = "vault-role-eu-west-1-amusing-rattler"
#  auth_type            = "iam"
#  bound_iam_role_arns  = ["arn:aws:iam::123361688033:role/vault-role-eu-west-1-amusing-rattler"]
#  inferred_entity_type = "ec2_instance"
#  inferred_aws_region  = "eu-west-1"
#  token_ttl            = 60
#  token_max_ttl        = 120
#  token_policies       = ["default"]
#}

resource "vault_policy" "example" {
  name = "devwebapp"

  policy = <<EOT
path "secret/data/web" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kv_secret_v2" "example" {
  mount               = "secret/" #when in dev mode
  name                = "web"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      zip = "zap",
      foo = "bar"
    }
  )
}

#This role (wif-irsa-demo-role) is created outside of TF, it must pre-exists, check consume/consume_role.sh
resource "vault_aws_auth_backend_role" "aws_iam_type_auth_wif" {
  backend                  = vault_auth_backend.aws.path
  role                     = "wif-demo-acc-role"
  auth_type                = "iam"
  bound_iam_principal_arns = ["arn:aws:iam::123361688033:role/wif-irsa-demo-role"]
  token_ttl                = 60
  token_max_ttl            = 120
  token_policies           = ["devwebapp"]
}
#
#resource "vault_aws_auth_backend_role" "aws_iam_type_auth" {
#  backend              = vault_auth_backend.aws.path
#  role                 = "vault-role-eu-west-1-amusing-rattler"
#  auth_type            = "iam"
#  bound_iam_role_arns  = ["arn:aws:iam::123361688033:role/vault-role-eu-west-1-amusing-rattler"]
#  inferred_entity_type = "ec2_instance"
#  inferred_aws_region  = "eu-west-1"
#  token_ttl            = 60
#  token_max_ttl        = 120
#  token_policies       = ["default"]
#}