resource "aws_ecs_cluster" "monitor" {
  name = "monitor"
}

resource "aws_security_group" "monitor" {
  name   = "ecs-instance-monitor"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs_instance_monitor" {
  name               = "ecsInstanceMonitor"
  assume_role_policy = "${data.aws_iam_policy_document.assume_ec2.json}"
}

resource "aws_iam_instance_profile" "ecs_instance_monitor" {
  name = "ecsInstanceMonitor"
  role = "${aws_iam_role.ecs_instance_monitor.name}"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_monitor_acces_ecs" {
  role       = "${aws_iam_role.ecs_instance_monitor.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_monitor_acess_ec2" {
  role       = "${aws_iam_role.ecs_instance_monitor.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_instance" "monitor" {
  ami                         = "${data.aws_ssm_parameter.ecs_instance_ami.value}"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.ecs_instance_monitor.name}"
  subnet_id                   = "${aws_subnet.public.id}"
  vpc_security_group_ids      = ["${aws_security_group.monitor.id}"]
  key_name                    = "${var.ssh_key}"

  user_data = <<EOF
#!/bin/bash

echo ECS_CLUSTER=monitor >> /etc/ecs/ecs.config
EOF

  tags {
    Name = "monitor"
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family = "prometheus"

  container_definitions = <<EOF
[
  {
    "name": "prometheus",
    "image": "prom/prometheus",
    "cpu": 10,
    "memory": 128,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 9090,
        "hostPort": 9090
      }
    ],
    "command": ["--config.file=/etc/prometheus/prometheus.yml", "--web.enable-lifecycle"]
  }
]
EOF
}

resource "aws_ecs_service" "prometheus" {
  name                               = "prometheus"
  cluster                            = "${aws_ecs_cluster.monitor.id}"
  task_definition                    = "${aws_ecs_task_definition.prometheus.arn}"
  desired_count                      = "1"
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
}

resource "aws_ecs_task_definition" "grafana" {
  family = "grafana"

  container_definitions = <<EOF
[
  {
    "name": "grafana",
    "image": "grafana/grafana",
    "cpu": 10,
    "memory": 128,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 3000
      }
    ]
  }
]
EOF
}

resource "aws_ecs_service" "grafana" {
  name                               = "grafana"
  cluster                            = "${aws_ecs_cluster.monitor.id}"
  task_definition                    = "${aws_ecs_task_definition.grafana.arn}"
  desired_count                      = "1"
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
}
