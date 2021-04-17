terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.37.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY INTO THE DEFAULT VPC AND SUBNETS
# To keep this example simple, we are deploying into the Default VPC and its subnets. In real-world usage, you should
# deploy into a custom VPC and private subnets. Given the subnet group needs to span multiple AZs and hence subnets we
# have deployed it across all the subnets of the default VPC.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN SUBNET GROUP ACROSS ALL THE SUBNETS OF THE DEFAULT ASG TO HOST THE RDS INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_subnet_group" "example" {
  name       = "terratest-example"
  subnet_ids = data.aws_subnet_ids.all.ids
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A CUSTOM PARAMETER GROUP AND AN OPTION GROUP FOR CONFIGURABILITY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_option_group" "example" {
  name                     = "terratest-example"
  engine_name              = "mysql"
  major_engine_version     = "8.0"
}

resource "aws_db_parameter_group" "example" {
  name        = "terratest-example"
  family      = "mysql8.0"

  parameter {
    name  = "general_log"
    value = "0"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO ALLOW ACCESS TO THE RDS INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "db_instance" {
  name   = "terratest-example"
  vpc_id = data.aws_vpc.default.id

}

resource "aws_security_group_rule" "allow_db_access" {
  type              = "ingress"
  from_port         = "3306"
  to_port           = "3306"
  protocol          = "tcp"
  security_group_id = aws_security_group.db_instance.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE DATABASE INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_instance" "example" {
  identifier              = "terratest-example"
  engine                  = "mysql"
  engine_version          = "8.0.23"
  port                    = "3306"
  name                    = "testmysqldatabase"
  username                = "test_mysql_db"
  password                = var.password
  instance_class          = "db.t2.micro"
  allocated_storage       = "5"
  skip_final_snapshot     = true
  license_model           = "general-public-license"
  db_subnet_group_name    = aws_db_subnet_group.example.id
  vpc_security_group_ids  = [aws_security_group.db_instance.id]
  publicly_accessible     = true
  parameter_group_name    = aws_db_parameter_group.example.id
  option_group_name       = aws_db_option_group.example.id
}
