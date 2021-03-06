# README.txt

Example of how to create a trivial, unsecure aws ecs setup using terraform.


## Install Terraform

mkdir terraform

cd terraform

wget https://releases.hashicorp.com/terraform/0.10.7/terraform_0.10.7_linux_amd64.zip

unzip terraform*


Add the following lines to ~/.bashrc

export path to Terraform

export PATH=$PATH:/home/kj/terraform


re-login


## Create a sample docker image

I have created a spring boot hello world application

create a docker image:

mvn clean package docker:build


## Publish docker image to aws ecr repository

The following command:

aws ecr get-login --no-include-email --region us-west-2 

generates a command that you need to run

copy and run the command


next run the following commands to push your image to ecr

docker images

docker tag your_ image_ id your_ aws_ ecr_ repository

docker push your_ aws_ ecr_ repository


## Run terraform template to install your docker image on aws ecs

First create the ssh key called kj_terraform_key

cd keys

ssh-keygen


Next export variables:

export AWS_ACCESS_KEY_ID=your_ access_ key

export AWS_SECRET_ACCESS_KEY=your_ secret_ key

export AWS_DEFAULT_REGION="us-west-2"


Finally execute terraform:

terraform init

terraform plan

terraform apply


## Test

http://public_ip:8080/swagger-ui.html


