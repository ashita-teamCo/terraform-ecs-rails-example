resource "aws_vpc" "this" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnet_cidr_list)
  vpc_id = aws_vpc.this.id

  cidr_block = each.value
  availability_zone = var.az_list[index(var.public_subnet_cidr_list, each.value)]

  tags = {
    Name = "${var.name}-public-${each.value}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name
  }
}

resource "aws_eip" "natgw" {
  for_each = toset(var.public_subnet_cidr_list)
  vpc = true

  tags = {
    Name = "${var.name}-natgw-${each.value}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = toset(var.public_subnet_cidr_list)

  subnet_id = aws_subnet.public[each.value].id
  allocation_id = aws_eip.natgw[each.value].id

  tags = {
    Name = "${var.name}-${each.value}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id = aws_route_table.public.id
  gateway_id = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = toset(var.public_subnet_cidr_list)

  subnet_id = aws_subnet.public[each.value].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  for_each = toset(var.private_subnet_cidr_list)
  vpc_id = aws_vpc.this.id

  cidr_block = each.value
  availability_zone = var.az_list[index(var.private_subnet_cidr_list, each.value)]

  tags = {
    Name = "${var.name}-private-${each.value}"
  }
}

resource "aws_route_table" "private" {
  for_each = toset(var.private_subnet_cidr_list)
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private-${each.value}"
  }
}

resource "aws_route" "private" {
  for_each = toset(var.private_subnet_cidr_list)

  destination_cidr_block = "0.0.0.0/0"
  route_table_id = aws_route_table.private[each.value].id
  nat_gateway_id = aws_nat_gateway.this[
    element(var.public_subnet_cidr_list, index(var.private_subnet_cidr_list, each.value))
  ].id
}

resource "aws_route_table_association" "private" {
  for_each = toset(var.private_subnet_cidr_list)

  subnet_id = aws_subnet.private[each.value].id
  route_table_id = aws_route_table.private[each.value].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.this.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Name = "s3"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  for_each = aws_route_table.private

  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  route_table_id = each.value.id
}

resource "aws_security_group" "vpc_endpoint" {
  name = "vpc_endpoint_sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
}

resource "aws_vpc_endpoint" "ecr" {
  for_each = toset(
    [
      "ecr.dkr",
      "ecr.api",
      "ssm",
      "logs",
      "ec2messages",
      "ec2",
      "ssmmessages",
      "kms"
    ]
  )

  vpc_id  = aws_vpc.this.id
  service_name = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type = "Interface"
  subnet_ids = values(aws_subnet.private)[*]["id"]
  security_group_ids = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = each.value
  }
}
