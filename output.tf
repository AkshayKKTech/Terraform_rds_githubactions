output "vpc_id" {
    value = aws_vpc.rds_vpc.id
}

output "public_subnet_ids" {
    value = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
    value = aws_subnet.private_subnet[*].id
}

output "rds_endpoint" {
    value = aws_db_instance.rds_instance.endpoint
}

output "rds_address" {
    value = aws_db_instance.rds_instance.address
}