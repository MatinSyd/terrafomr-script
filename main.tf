# Creating VPC 
resource "aws_vpc" "TF-VPC" { 
 cidr_block = "192.168.0.0/16" 
 instance_tenancy = "default" 
tags = { 
 Name = "TF-VPC" 
} 
} 

# Creating public subnet 
resource "aws_subnet" "public-sub" {
 vpc_id = "vpc-0e971a2c2041b0474"
 cidr_block = "192.168.100.0/24"
 map_public_ip_on_launch = true
 availability_zone = "us-west-2a"
tags = {
 Name = "public-sub"
}
}
# Creating private subnet 
resource "aws_subnet" "private-sub" {
 vpc_id = "vpc-0e971a2c2041b0474"
 cidr_block = "192.168.200.0/24"
 map_public_ip_on_launch = false 
 availability_zone = "us-west-2b"
tags = {
 Name = "private-sub"
}
}
# creating nat getway
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.private-sub.id
}

# Define the Elastic IP address for the NAT gateway
resource "aws_eip" "nat_eip" {
  vpc = true
}

# creating  virtual machine in the private subnet
resource "aws_instance" "private_vm" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_sub.id

  # Login credentials for the virtual machine
  key_name      = "my_key_pair"
  user_data     = file("")

  # Attach Elastic IP to the instance for public access
  associate_public_ip_address = true
}

# creating  a security group to allow traffic to the NAT gateway and the virtual machine
resource "aws_security_group" "nat_security_group" {
  name_prefix = "nat-security-group"
  vpc_id      = aws_vpc.TF-VPC.id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    # Allow traffic to the NAT gateway
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    # Allow SSH access to the virtual machine
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # Allow HTTP access to the virtual machine
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    # Allow outbound traffic from the private subnet through the NAT gateway
    # This is required for traffic to reach the NAT gateway
    # and be translated to the public IP address of the gateway
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }
}

# creating a null_resource to execute the SSH command to check the public IP address of the private virtual machine
resource "null_resource" "ssh_check_private_vm_public_ip" {
  depends_on = [aws_instance.private_vm]
  connection {
    type = "ssh"
    host = aws_eip.nat_eip.public_ip
    user = "ec2-user"
    private_key = file("~/.ssh/my_key_pair.pem")
  }

  provisioner "remote-exec" {
    inline = [
      "curl ifconfig.me
