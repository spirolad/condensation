set: 

export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_SESSION_TOKEN=""

1 init

terraform init


2 plan

 terraform plan -var-file="environnement/prd.tfvars"

3 apply 

terraform plan -auto-approve -var-file="environnement/prd.tfvars"

4 destroy 

terraform destroy  -auto-approve -var-file="environnement/prd.tfvars"
