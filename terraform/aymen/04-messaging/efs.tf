# uid/gid confirmed by inspecting the actual built image:
#   docker run --rm --entrypoint getent cloud-design-rabbit-queue passwd rabbitmq
#   -> rabbitmq:x:101:103:...
locals {
  rabbitmq_uid = 101
  rabbitmq_gid = 103
}

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Allow NFS only from the rabbit-queue task"
  vpc_id      = local.vpc_id

  ingress {
    description     = "NFS from rabbit-queue"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [local.rabbitmq_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-efs-sg"
  }
}

resource "aws_efs_file_system" "rabbitmq" {
  encrypted = true

  tags = {
    Name = "${var.project_name}-rabbitmq-data"
  }
}

resource "aws_efs_mount_target" "rabbitmq" {
  count           = length(local.private_subnet_ids)
  file_system_id  = aws_efs_file_system.rabbitmq.id
  subnet_id       = local.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "rabbitmq" {
  file_system_id = aws_efs_file_system.rabbitmq.id

  posix_user {
    uid = local.rabbitmq_uid
    gid = local.rabbitmq_gid
  }

  root_directory {
    path = "/rabbitmq"
    creation_info {
      owner_uid   = local.rabbitmq_uid
      owner_gid   = local.rabbitmq_gid
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.project_name}-rabbitmq-ap"
  }
}
