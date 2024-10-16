#https://lucid.app/lucidchart/bf9f35e1-fd91-403c-bff8-3b8f379d7a98/edit?beaconFlowId=ED0C18F6D017D270&invitationId=inv_2cb79f7a-308b-4054-ae56-2eaffa511e1b&page=0_0

#Vault injector should be installed first using the values.yaml
#helm install vault-wif hashicorp/vault -f default_values.yaml

# Add trust relations so IRSA OIDC provider can assume it via the AWS 
# The OIDC provider of K8S EKS cluster
export PROVIDER_ARN=arn:aws:iam::123361688033:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/6214054D9FE5A8901A7FB7511FD78C12
export ISSUER_HOSTPATH=$(aws eks describe-cluster --region eu-central-1 --name k8s-training-martin --query cluster.identity.oidc.issuer --output text | cut -f 3- -d'/')
#SA that will be used to run the K8S pod
export SA_NAME=wif-demo-acc

cat > irp-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${ISSUER_HOSTPATH}:sub": "system:serviceaccount:default:$SA_NAME"
        }
      }
    }
  ]
}
EOF


export ROLE_NAME=wif-irsa-demo-role

aws iam create-role \
          --role-name $ROLE_NAME \
          --assume-role-policy-document file://irp-trust-policy.json
aws iam update-assume-role-policy \
          --role-name $ROLE_NAME \
          --policy-document file://irp-trust-policy.json
DEMO_ROLE_ARN=$(aws iam get-role \
                        --role-name $ROLE_NAME \
                        --query Role.Arn --output text)

echo $ROLE_ARN

#Creating and annotating the SA used for the demo pod
k create sa $SA_NAME
k annotate sa $SA_NAME -n default "eks.amazonaws.com/role-arn=$DEMO_ROLE_ARN"
k describe sa $SA_NAME

# Policy to read KV secret
vault policy write devwebapp - <<EOF
path "secret/data/web" {
  capabilities = ["read"]
}
EOF
# if not dev server - vault secrets enable -path=secret kv-v2

# Write sample KV secret
# vault secrets enable -path=secret kv-v2 IF not DEV
vault kv put secret/web foo=bar

#sample Ubuntu pod which consumes the secret 
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-vault-wif-aws-ubuntu
  annotations:
        vault.hashicorp.com/agent-inject: 'true'
        vault.hashicorp.com/auth-type: "aws"
        vault.hashicorp.com/auth-config-type: "iam"
        vault.hashicorp.com/auth-path: "auth/aws"
        vault.hashicorp.com/role: 'wif-demo-acc-role'
        vault.hashicorp.com/agent-inject-secret-config: 'secret/data/web'
        # Environment variable export template
        vault.hashicorp.com/agent-inject-template-config: |
          {{ with secret "secret/data/web" -}}
            export api_key="{{ .Data.data.foo }}"
          {{- end }}
spec:
  serviceAccountName: wif-demo-acc
  containers:
  - name: ubuntu
    image: ubuntu
    command: ["/bin/sleep", "999999"]
EOF