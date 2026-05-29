# ==========================================
# NETZWERK-INFRASTRUKTUR (VPC)
# ==========================================

resource "aws_vpc" "modul300_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "modul300-vpc" }
}

# Öffentliches Subnet (für Ansible Controller)
resource "aws_subnet" "public_sub" {
  vpc_id                  = aws_vpc.modul300_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "modul300-public-subnet" }
}

# Privates Subnet für das K3s-Cluster
resource "aws_subnet" "private_compute_sub" {
  vpc_id            = aws_vpc.modul300_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "modul300-private-compute" }
}

# Privates Subnet für das Backup-Management
resource "aws_subnet" "private_storage_sub" {
  vpc_id            = aws_vpc.modul300_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "modul300-private-storage" }
}

# Internet Gateway für das Public Subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.modul300_vpc.id
  tags   = { Name = "modul300-igw" }
}

# Route Table für Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.modul300_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "modul300-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_sub.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway damit private Instanzen Updates/Packages laden können
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "modul300-nat-eip" }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_sub.id
  tags          = { Name = "modul300-nat-gw" }
}

# Route Table für Private Subnets (via NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.modul300_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = { Name = "modul300-private-rt" }
}

resource "aws_route_table_association" "private_compute_assoc" {
  subnet_id      = aws_subnet.private_compute_sub.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_storage_assoc" {
  subnet_id      = aws_subnet.private_storage_sub.id
  route_table_id = aws_route_table.private_rt.id
}
