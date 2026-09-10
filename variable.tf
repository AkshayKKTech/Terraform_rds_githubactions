variable "vpc_cidr" {
    description = "vpc configuration"
    type = string
    default = "10.0.0.0/16"
    
}

variable "environment" {
    description = "environment"
    type = string
    default = "dev"
}

variable "rds_instance_class" {
    description = "RDS instance class"
    type = string
    default = "db.t3.micro"
}

variable "aws_region" {
    description = "aws region"
    type = string
    default = "us-east-1"
}

variable "db_name" {
    description = "Database name"
    type = string
    default = "mydb"
}

variable "db_username" {
    description = "Database username"
    type = string
    default = "prosgress"
}
