data "aws_availability_zones" "az" {
    state = "available"
}


resource "aws_vpc" "rds_vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
    Name = var.environment
    }
}



resource "aws_subnet" "public_subnet" {
    count = 2
    vpc_id = aws_vpc.rds_vpc.id
    cidr_block = cidrsubnet(var.vpc_cidr, 4, count.index)
    availability_zone = data.aws_availability_zones.az.names[count.index]
    map_public_ip_on_launch = true

    tags = {
        Name = "${var.environment}-public-subnet-${count.index + 1}"
    }

}

resource "aws_subnet" "private_subnet" {
    count = 2
    vpc_id = aws_vpc.rds_vpc.id
    cidr_block =cidrsubnet(var.vpc_cidr, 4, count.index +2)
    availability_zone = data.aws_availability_zones.az.names[count.index]

    tags = {
        Name = "${var.environment}-private-subnet-${count.index + 1}"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.rds_vpc.id

    tags = {
        Name = "${var.environment}-igw"
    }
}

resource "aws_eip" "nat_eip" {
    domain = "vpc"
    depends_on = [aws_internet_gateway.igw]

    tags = {
        Name = "${var.environment}-nat-eip"
    }
}

resource "aws_nat_gateway" "nat_gw" {
    subnet_id = aws_subnet.public_subnet[0].id
    allocation_id = aws_eip.nat_eip.id

    tags = { 
        Name = "${var.environment}-nat-gw"
    }
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.rds_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "${var.environment}-public-rt"
    }
}

resource "aws_route_table_association" "public_rt_assoc" {
    count = 2
    subnet_id = aws_subnet.public_subnet[count.index].id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.rds_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gw.id
    }

    tags = {
        Name = "${var.environment}-private-rt"
    }
}

resource "aws_route_table_association" "private_rt_assoc" {
    count = 2
    subnet_id = aws_subnet.private_subnet[count.index].id
    route_table_id = aws_route_table.private_rt.id
}

#######
# database
#######

resource "aws_security_group" "rds_sg" {
    name = "${var.environment}-rds-sg"
    description = "Security group for RDS"
    vpc_id = aws_vpc.rds_vpc.id

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = [var.vpc_cidr]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.environment}-rds-sg"
    }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
    name = "${var.environment}-rds-subnet-group"
    subnet_ids = aws_subnet.private_subnet[*].id

    tags = {
        Name = "${var.environment}-rds-subnet-group"
    }
}

resource "aws_db_parameter_group" "rds_pg" {
    name = "${var.environment}-rds-pg"
    family = "postgres16"

    parameter {
        name = "log_connections"
        value = "1"
    }
}

resource "aws_db_instance" "rds_instance" {
    identifier = "${var.environment}-rds-instance"

    engine = "postgres"
    engine_version = "16.3"
    instance_class = var.rds_instance_class

    allocated_storage = 20
    max_allocated_storage = 100
    storage_type = "gp3"
    storage_encrypted = true

    multi_az = true

    db_name = var.db_name
    username = var.db_username
    password = random_password.db_password.result
    port = 5432

    db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
    vpc_security_group_ids = [aws_security_group.rds_sg.id]
    publicly_accessible = false

    parameter_group_name = aws_db_parameter_group.rds_pg.name
    backup_retention_period = 1
    backup_window = "03:00-04:00"
    maintenance_window = "sun:05:00-sun:06:00"
    deletion_protection = false
    skip_final_snapshot = true

    tags = {
        Name = "${var.environment}-rds-db"
    }
}

resource "random_password" "db_password" {
    length = 16
    special = true
    override_special = "!#$%&*()-_=+[]{}<>:?"
    
}

resource "aws_secretsmanager_secret" "db_secret" {
    name = "${var.environment}-db-secret"
    description = "RDS database credentials"

    tags = {
        Name = "${var.environment}-db-secret"
    }
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
    secret_id = aws_secretsmanager_secret.db_secret.id
    secret_string = jsonencode({
        username = var.db_username
        password = random_password.db_password.result
        engine   = "postgres"
        host     = aws_db_instance.rds_instance.address
        port     = aws_db_instance.rds_instance.port
        db_name  = var.db_name
  })
}
