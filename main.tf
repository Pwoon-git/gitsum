provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "phillsvpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "phillsvpc"
  }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id     = aws_vpc.phillsvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "phillsvpc-public-a"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id     = aws_vpc.phillsvpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "phillsvpc-public-b"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id     = aws_vpc.phillsvpc.id
  cidr_block = "192.168.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "phillsvpc-private-a"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id     = aws_vpc.phillsvpc.id
  cidr_block = "192.168.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "phillsvpc-private-b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.phillsvpc.id
  tags = {
    Name = "phillsvpc-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.phillsvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "phillsvpc-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id
  tags = {
    Name = "phillsvpc-nat"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.phillsvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "phillsvpc-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

# EKS Cluster
resource "aws_eks_cluster" "phillsvpc_eks" {
  name     = "phillsvpc-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
  }
  
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy, aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy]
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "phillsvpc-eks-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_eks_node_group" "phillsvpc_eks_node_group" {
  cluster_name    = aws_eks_cluster.phillsvpc_eks.name
  node_group_name = "phillsvpc-eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private_subnet_a.id]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  instance_type = "t2.large"
  depends_on    = [aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy, aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly, aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy]
}

resource "aws_iam_role" "eks_node_role" {
  name = "phillsvpc-eks-node-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

# EC2 Launch Template
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_launch_template" "ubuntu_lt" {
  name = "phillsvpc-ubuntu-lt"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 30
      volume_type           = "gp2"
    }
  }

  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.public_subnet_a.id
    security_groups             = [aws_security_group.public_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "phillsvpc-ubuntu-instance"
    }
  }
}

resource "aws_instance" "ubuntu_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  launch_template {
    id      = aws_launch_template.ubuntu_lt.id
    version = "$Latest"
  }
  subnet_id              = aws_subnet.public_subnet_a.id
  associate_public_ip_address = true

  tags = {
    Name = "phillsvpc-ubuntu-instance"
  }
}

resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.phillsvpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "phillsvpc-public-sg"
  }
}
