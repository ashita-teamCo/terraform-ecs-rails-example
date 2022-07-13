output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids"  {
  value = values(aws_subnet.public)[*]["id"]
}

output "private_subnet_ids"  {
  value = values(aws_subnet.private)[*]["id"]
}

output "az_list"  {
  value = var.az_list
}
