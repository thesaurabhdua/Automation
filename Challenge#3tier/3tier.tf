provider "aws" {
    region = var.region_name
}

data "aws_ssm_parameter" "linux_latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "complete-web"

  cidr = "10.10.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.3.0/24", "10.10.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "http from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_http"
  }
}
resource "aws_security_group" "bastion_sg" {
  description = "SSH ingress to Bastion and SSH egress to App"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group_rule" "in_ssh_bastion_from_anywhere" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_sg.id
}


resource "aws_security_group_rule" "in_ssh_app_from_bastion" {
  type                     = "ingress"
  description              = "Allow SSH from a Bastion Security Group"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_http.id
  source_security_group_id = aws_security_group.bastion_sg.id
}
## Creating Bastion host
resource "aws_instance" "jump_box" {
  ami           = data.aws_ssm_parameter.linux_latest_ami.value
  instance_type = var.jump_box_instance_type
  key_name      = var.jump_box_keyname
  subnet_id = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.allow_http.id, aws_security_group.bastion_sg.id]

  tags = {
    Name = "jump_box"
  }
}
## Creating Launch Configuration and ASG
resource "aws_launch_configuration" "web" {
  image_id               = var.ami_id
  instance_type          = "t2.micro"
  security_groups        = [aws_security_group.allow_http.id, aws_security_group.bastion_sg.id]
  key_name = "app-key"
  user_data = <<-EOF
              #!/bin/bash
              sudo service start nginx
              EOF

}
## Creating AutoScaling Group
resource "aws_autoscaling_group" "web" {
  launch_configuration = "${aws_launch_configuration.web.id}"
  vpc_zone_identifier  = module.vpc.private_subnets
  min_size = 2
  max_size = 4
  load_balancers = ["${aws_elb.web.name}"]
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "terraform-asg-web"
    propagate_at_launch = true
  }
}

resource "aws_elb" "web" {
  name = "terraform-asg-web"
  security_groups = ["${aws_security_group.allow_http.id}"]
  subnets = module.vpc.public_subnets

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

}
#####
# DB
#####
resource "aws_security_group" "allow_sql" {
  name        = "allow_sql"
  description = "Allow inbound traffic"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.allow_http.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#####
# DB
#####
data "aws_kms_secrets" "db" {
  secret {
    name    = "dbpassword"
    payload = "AQICAHiRGk/XUjhpx3Ym2xM5AELJ6tVV5Ea+90KZt4xag5GHJQHacuN92XDgxlhkDzV9jd9jAAAAZzBlBgkqhkiG9w0BBwagWDBWAgEAMFEGCSqGSIb3DQEHATAeBglghkgBZQMEAS4wEQQMp+BgV3TM8OpIS72OAgEQgCS7A71Mk4n3+ZtjzFjEDLHcJLTfB3GwLwhRFEYO5DD7EEqhWIQ="

  }
}

resource "aws_rds_cluster" "default" {
  cluster_identifier      = "aurora-cluster-demo"
  availability_zones      = module.vpc.private_subnets
  database_name           = "mydb"
  master_username         = "root"
  master_password         = data.aws_kms_secrets.db.plaintext["dbpassword"]
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
}
