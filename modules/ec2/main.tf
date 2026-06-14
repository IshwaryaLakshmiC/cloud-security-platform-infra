data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "app" {
  key_name   = "${var.project}-key"
  public_key = var.public_key
  tags       = var.tags
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"  # Free tier
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.app_security_group_id]
  key_name               = aws_key_pair.app.key_name
  iam_instance_profile   = var.instance_profile_name

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    db_host     = var.db_host
    db_port     = var.db_port
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
    aws_region  = var.region
  }))

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
    encrypted   = true
  }

  metadata_options {
    http_tokens                 = "required"  # IMDSv2 enforced
    http_put_response_hop_limit = 1
  }

  tags = merge(var.tags, { Name = "${var.project}-app-server" })
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.project}-eip" })
}
