provider "aws" {
}

resource "aws_vpc" "kj-vpc" {
  cidr_block = "${var.vpc_cidr}"
  tags { Name = "kj-vpc" }
}

resource "aws_internet_gateway" "kj-gw" {
  vpc_id = "${aws_vpc.kj-vpc.id}"
  tags { Name = "kj-gw" }
}

resource "aws_default_route_table" "default_routing" {
  default_route_table_id = "${aws_vpc.kj-vpc.default_route_table_id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.kj-gw.id}"
  }
  tags { Name = "kj-default-route" }
}

resource "aws_subnet" "kj-public" {
  vpc_id = "${aws_vpc.kj-vpc.id}"
  availability_zone = "us-west-2a"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags { Name = "kj-public" }
}

# Security

resource "aws_security_group" "kj-allow-ssh" {
  name = "kj-allow-ssh"
  description = "Allow SSH access"
  vpc_id = "${aws_vpc.kj-vpc.id}"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags { Name = "kj-sgroup-ssh"}
}

resource "aws_key_pair" "kj_terraform_key" {
  key_name = "kj_terraform_key"
  public_key = "${file("keys/kj_terraform_key.pub")}"
}

resource "aws_security_group" "kj-allow-http" {
  name = "kj-allow-http"
  description = "Allow HTTP traffic"
  vpc_id = "${aws_vpc.kj-vpc.id}"
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags { Name = "kj-sgroup-http"}
}

# ECS resources

resource "aws_ecs_cluster" "kj-ecc" {
  name = "kj-ecc"
}

# Profiles

resource "aws_iam_role" "kj-ecs-role" {
  name = "kj-ecs-role"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
]
}
EOF
}

resource "aws_iam_role_policy" "kj-ecs-role-policy" { 
  name = "kj-ecs-role-policy"
  role = "${aws_iam_role.kj-ecs-role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecs:StartTask",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "kj-instance-profile2" {
  name = "kj-instance-profile2"
  role = "${aws_iam_role.kj-ecs-role.name}"
}

# Load Balancer

resource "aws_elb" "kj-load-balancer" {
  name = "kj-load-balancer"
  subnets = ["${aws_subnet.kj-public.id}"]
  security_groups = ["${aws_security_group.kj-allow-http.id}"]
  cross_zone_load_balancing = true
  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  tags { Name = "kj-elb"}
}

# Autoscaling resources

resource "aws_launch_configuration" "kj-config" {
  image_id = "ami-29f80351"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.kj-allow-ssh.id}", "${aws_security_group.kj-allow-http.id}"]
  key_name      = "kj_terraform_key"
  iam_instance_profile = "${aws_iam_instance_profile.kj-instance-profile2.name}"
  lifecycle {
    create_before_destroy = true
  }
  user_data = "#!/bin/bash\necho ECS_CLUSTER=kj-ecc > /etc/ecs/ecs.config"
}

resource "aws_autoscaling_group" "kj-autoscaling-group" {
  vpc_zone_identifier = ["${aws_subnet.kj-public.id}"]
  name = "kj-autoscaling-group - ${aws_launch_configuration.kj-config.name}"
  max_size = "1"
  min_size = "1"
  launch_configuration = "${aws_launch_configuration.kj-config.name}"
#  load_balancers = ["${aws_elb.kj-load-balancer.id}"]
  lifecycle {
    create_before_destroy = true
  }
}

# Repository and task

resource "aws_ecr_repository" "kj-repository" {
  name = "kj-repository"
}

resource "aws_ecs_task_definition" "kj-task" {
  family                = "kj-task"
  container_definitions = <<EOF
[
  {
    "name": "rest-api",
    "image": "940671628147.dkr.ecr.us-west-2.amazonaws.com/kj-repository:latest",
    "cpu": 1,
    "memory": 512,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ]
  }
]
EOF
  volume {
    name      = "service-storage"
    host_path = "/ecs/service-storage"
  }
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}

resource "aws_ecs_service" "kj-ecs" {
  name            = "kj-ecs"
  cluster	  = "${aws_ecs_cluster.kj-ecc.name}"
  task_definition = "${aws_ecs_task_definition.kj-task.arn}"
  desired_count   = 1
#  iam_role        = "${aws_iam_role.kj-ecs-role.arn}"
#  load_balancer {
#    elb_name       = "${aws_elb.kj-load-balancer.name}"
#    container_name = "kj-ecs"
#    container_port = 8080
#  }
  placement_strategy {
    type  = "binpack"
    field = "cpu"
  }
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}

