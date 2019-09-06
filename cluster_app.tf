resource "aws_ecs_cluster" "app" {
  name = "app"
}

resource "aws_security_group" "app" {
  name   = "ecs-instance-app"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "TCP"
    security_groups = ["${aws_security_group.monitor.id}"]

    # cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs_instance_app" {
  name               = "ecsInstanceApp"
  assume_role_policy = "${data.aws_iam_policy_document.assume_ec2.json}"
}

resource "aws_iam_instance_profile" "ecs_instance_app" {
  name = "ecsInstanceApp"
  role = "${aws_iam_role.ecs_instance_app.name}"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_app_acces_ecs" {
  role       = "${aws_iam_role.ecs_instance_app.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_instance" "app" {
  ami                         = "${data.aws_ssm_parameter.ecs_instance_ami.value}"
  instance_type               = "t2.micro"
  associate_public_ip_address = "true"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs_instance_app.name}"
  key_name                    = "${var.ssh_key}"
  subnet_id                   = "${aws_subnet.public.id}"
  vpc_security_group_ids      = ["${aws_security_group.app.id}"]

  user_data = <<EOF
#!/bin/bash

echo ECS_CLUSTER=app >> /etc/ecs/ecs.config
EOF

  tags = {
    Name = "app"
  }
}

resource "aws_ecs_task_definition" "nginx" {
  family = "nginx"

  container_definitions = <<EOF
[
  {
    "name": "nginx",
    "image": "nginx",
    "cpu": 10,
    "memory": 128,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
EOF
}

resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = "${aws_ecs_cluster.app.id}"
  task_definition = "${aws_ecs_task_definition.nginx.arn}"
  desired_count   = "1"
}

resource "aws_ecs_task_definition" "cadvisor" {
  family = "cadvisor"

  volume {
    name      = "root"
    host_path = "/"
  }

  volume {
    name      = "var_run"
    host_path = "/var/run"
  }

  volume {
    name      = "sys"
    host_path = "/sys"
  }

  volume {
    name      = "var_lib_docker"
    host_path = "/var/lib/docker"
  }

  volume {
    name      = "dev_disk"
    host_path = "/dev_disk"
  }

  volume {
    name      = "cgroup"
    host_path = "/cgroup"
  }

  container_definitions = <<EOF
[
  {
    "name": "cadvisor",
    "image": "google/cadvisor",
    "cpu": 10,
    "memory": 300,
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ],
    "essential": true,
    "privileged": true,
    "mountPoints": [
      {
        "sourceVolume": "root",
        "containerPath": "/rootfs",
        "readOnly": true
      },
      {
        "sourceVolume": "var_run",
        "containerPath": "/var/run",
        "readOnly": false
      },
      {
        "sourceVolume": "sys",
        "containerPath": "/sys",
        "readOnly": true
      },
      {
        "sourceVolume": "var_lib_docker",
        "containerPath": "/var/lib/docker",
        "readOnly": true
      },
      {
        "sourceVolume": "dev_disk",
        "containerPath": "/dev/disk",
        "readOnly": true
      },
      {
        "sourceVolume": "cgroup",
        "containerPath": "/sys/fs/cgroup",
        "readOnly": true
      }
    ]
  }
]
EOF
}

resource "aws_ecs_service" "cadvisor" {
  name                               = "cadvisor"
  cluster                            = "${aws_ecs_cluster.app.id}"
  task_definition                    = "${aws_ecs_task_definition.cadvisor.arn}"
  scheduling_strategy                = "DAEMON"
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
}
