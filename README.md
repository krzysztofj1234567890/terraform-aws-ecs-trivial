# README.txt

Example of how to create a trivial, unsecure aws ecs setup using terraform.


## Install Terraform

mkdir terraform
cd terraform

wget https://releases.hashicorp.com/terraform/0.10.7/terraform_0.10.7_linux_amd64.zip

unzip terraform*

Add the following lines ~/.bashrc
vi ~/.bashrc

export path to Terraform
export PATH=$PATH:/home/kj/terraform

re-login


## Create a sample docker image

I have created a spring boot hello world application

create a docker image:
mvn clean package docker:build


## Publish docker image to aws ecr repository

AWS Docker Registry
aws ecr get-login --no-include-email --region us-west-2 

the command above generates a command 
copy and run the command

docker images
docker tag <your image id> <your aws ecr repository>
docker push <your aws ecr repository>


## Run terraform tamplate to install contect-service on aws

export AWS_ACCESS_KEY_ID=<your access key>
export AWS_SECRET_ACCESS_KEY=<your secret key>
export AWS_DEFAULT_REGION="us-west-2"

terraform init
terraform plan
terraform apply


## Test

http://<public ip>:8080/swagger-ui.html


