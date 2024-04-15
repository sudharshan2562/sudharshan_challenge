

provider "aws" {
    region = "us-east-1"
    version = "v2.70.0"
}

# vpc

resource "aws_vpc" "srgvpc" {
   cidr_block       = "${var.vpc_cidr}"
   instance_tenancy = "default"
tags = {
   Name = "website  VPC"
 }
}


# Internet gateway

resource "aws_internet_gateway" "srggateway" {
  vpc_id = "${aws_vpc.srgvpc.id}"
}


# subnets

# Creating 1st subnet 
resource "aws_subnet" "srgsubnet-1" {
  vpc_id                  = "${aws_vpc.srgvpc.id}"
  cidr_block             = "${var.subnet1_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  tags = {
    Name = "srg subnet 1"
  }
}
# Creating 2nd subnet 
resource "aws_subnet" "srgsubnet-2" {
  vpc_id                  = "${aws_vpc.demovpc.id}"
  cidr_block             = "${var.subnet2_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"
  tags = {
    Name = "srg subnet 2"
  }
}


# route table

resource "aws_route_table" "route" {
  vpc_id = "${aws_vpc.srgvpc.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.demogateway.id}"
    }
  tags = {
      Name = "Route to internet"
    } 
}
resource "aws_route_table_association" "rt1" {
  subnet_id = "${aws_subnet.srgsubnet-1.id}"
  route_table_id = "${aws_route_table.route.id}"
}
resource "aws_route_table_association" "rt2" {
  subnet_id = "${aws_subnet.srgsubnet-2.id}"
  route_table_id = "${aws_route_table.route.id}"
}



# Security Group for ELB
resource "aws_security_group" "srgsg1" {
  name        = "srg Security Group"
  description = "srg Module"
  vpc_id      = "${aws_vpc.demovpc.id}"

# Inbound Rules
# HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
# HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
# SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
# Outbound Rules
# Internet access to anywhere
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
}


# Elastic load balancer

resource "aws_elb" "web_elb" {
name = "web-elb"
security_groups = [
  "${aws_security_group.srgsg1.id}"
]
subnets = [
  "${aws_subnet.srgsubnet-1.id}",
  "${aws_subnet.srgsubnet-2.id}"
]
cross_zone_load_balancing   = true
health_check {
  healthy_threshold = 2
  unhealthy_threshold = 2
  timeout = 3
  interval = 30
  target = "HTTP:80/"
}
listener {
  lb_port = 80
  lb_protocol = "http"
  instance_port = "80"
  instance_protocol = "http"
}
}


# http to https redirect
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


# https to target group
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::xxxxxxxxxx:server-certificate/xxxxxxxxxxxxxxxxxxx"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}

# target group for alb
resource "aws_lb_target_group" "alb_tg" {
  name = "alb-tg"
  target_type = "instance"
  port = 80
  protocol = "HTTPS"
  vpc_id = "${aws_vpc.srgvpc.id}"
}





# launch configuration

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"
  image_id = "ami-087c17d1fe0178315" 
  instance_type = "t2.micro"
  key_name = "tests"
  security_groups = [ "${aws_security_group.srg-sg.id}" ]
  associate_public_ip_address = true
  user_data = "${file("data.sh")}"
lifecycle {
  create_before_destroy = true
}
}


# Security Group for EC2 instances
resource "aws_security_group" "srgsg" {

  vpc_id      = "${aws_vpc.srgvpc.id}"

  # Inbound Rules
  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# autoscaling group for ec2 instances

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"
  min_size             = 1
  desired_capacity     = 1
  max_size             = 2

  health_check_type    = "ELB"
  target_group_arns = "${aws_lb_target_group.alb_tg.arn}"
  ]
launch_configuration = "${aws_launch_configuration.web.name}"
enabled_metrics = [
  "GroupMinSize",
  "GroupMaxSize",
  "GroupDesiredCapacity",
  "GroupInServiceInstances",
  "GroupTotalInstances"
]
metrics_granularity = "1Minute"
vpc_zone_identifier  = [
  "${aws_subnet.srgsubnet-1.id}",
  "${aws_subnet.srgsubnet-2.id}"
]
# Required to redeploy without an outage.
lifecycle {
  create_before_destroy = true
}
tag {
  key                 = "Name"
  value               = "web"
  propagate_at_launch = true
}
}

# autoscaling policy for ec2 instances

resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "70"
dimensions = {
  AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
}
alarm_description = "This metric monitor EC2 instance CPU utilization"
alarm_actions = [ "${aws_autoscaling_policy.web_policy_up.arn}" ]
}
resource "aws_autoscaling_policy" "web_policy_down" {
  name = "web_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "30"
dimensions = {
  AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
}
alarm_description = "This metric monitor EC2 instance CPU utilization"
alarm_actions = [ "${aws_autoscaling_policy.web_policy_down.arn}" ]
}


