## Simple PoC project that deploys API gateway and configures Vault as OIDC provider for AWS, so Vault server can utilize the WIF (Workload Indentity Federation) function.
-----

![Vault Logo](https://github.com/hashicorp/vault/raw/f22d202cde2018f9455dec755118a9b84586e082/Vault_PrimaryLogo_Black.png)


### What is it: 
  This project deploys a AWS API Gateway which exposes the needed OIDC endpoints for Vault to be considered a OIDC provider in AWS.
  Furthermore, WIF functionality of Vault Enterprise (enterprise license needed) is utilized to assume AWS role and make AWS auth method functional, even though Vault is running outside of AWS.
  The sole purpose of this project is to create a way of Vault server which is running outside of AWS to authenticate to AWS without the need of hardcoded credentials.

### Simple diagram:
![Diagram](https://lucid.app/publicSegments/view/e8da7097-299d-47f3-b3eb-2ac73b776118/image.png)

### Prerequisites:
  - Having AWS account
  - Pre-configured AWS EKS cluster with associated OIDC provider. Instructions on how to setup EKS cluster and OIDC provider for it can be found [here](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html) and [here](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) 
  - Terraform v1.9.5 or higher
  - Vault Enterprise server 1.17.0 and up
  - Pre-existing AWS role, which can be created via instructions described in `consume/consume_role.sh` file. It will be to login to the Vault server.

### Usage:
  - Clone the repository: `git clone https://github.com/martinhristov90/vault-aws-wif`.
  - Change into its directory: `cd vault-aws-wif`.
  - Create `terraform.tfvars` file, to override the default variable values described in `variables.tf`
  - Create the `wif-demo-acc` K8S SA and `wif-irsa-demo-role` AWS role, so the Ubuntu demo Pod can utilize this particular AWS role to login to the Vault server, this can be achieved by following instructions in `consume/consume_role.sh` script. Values of `PROVIDER_ARN`, `ISSUER_HOSTPATH` must be adjusted according to your AWS EKS configuration.
  - Install Vault injector via `helm install vault-wif hashicorp/vault -f values.yaml`, using the `values.yaml` file provided in `consume/` directory. The address of NGROK should be adjusted.
  - Start NGROK at the desired address.
  - Initialize Terraform providers: `terraform init`.
  - Start Vault Enterprise server (1.17.0 and up) locally with the following command: `vault server -dev -dev-listen-address=0.0.0.0:8200 --log-level=TRACE -dev-root-token-id=root -dev-ha -dev-transactional`
  - Execute Terraform plan and apply: `terraform plan` and `terraform apply`.

### `terraform.tfvars` explanation and example:

  | Variable | Example | Meaning |
  | :--- | :---- | :--- |
  |public_oidc_issuer_url| https://vault-plugin-wif.mhristov.sbx.hashidemos.io|Subdomain of the hosted zone, which will be used to exposed OIDC endpoints|
  |aws_audience|sts.amazonaws.com|Audience for the JWT tokens exchanged between AWS and Vault|
  |vault_addr|https://marti.ngrok.io|Publicly accessible address of Vault server, in this case NGROK is utilized|
  |vault_namespace|""|Vault namespace in which the AWS auth method is mouted, empty means root namespace|
  |hosted_zone|mhristov.sbx.hashidemos.io|Hosted zone which the API Gateway uses to server OIDC endpoints|

#### Example `terraform.tfvars` file:
  ```
  public_oidc_issuer_url="https://vault-plugin-wif.mhristov.sbx.hashidemos.io"
  aws_audience="sts.amazonaws.com"
  vault_addr="https://marti.ngrok.io"
  vault_namespace=""
  hosted_zone="mhristov.sbx.hashidemos.io"
  ```

-----
### TODO:
  - [ ] Integreate the creation of demo Pod and AWS demo role into TF 
### License:
  - [MIT](https://choosealicense.com/licenses/mit/)