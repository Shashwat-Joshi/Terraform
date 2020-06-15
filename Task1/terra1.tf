// Providing login credentials and region
provider "aws" {
  region  = "ap-south-1"
  profile = "terraformUser"
}

// Creating Key Pair
# resource "aws_key_pair" "key1" {
#   key_name   = "terraform-key"
#   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 shashwat2002joshi@gmail.com"
# }

// Creating Security group that allows Port 22 (ssh) and 80 (http)
resource "aws_security_group" "allow_tls" {
  name        = "terraform-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-92ecf1fa"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
    Name = "terraform-sg"
  }
}

// Creating Instance using above created security group and already created key
resource "aws_instance" "instance1" {
  ami             = "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name        = "key"
  security_groups = ["terraform-sg"]

  tags = {
    Name = "terraformOS"
  }
}


// How to print values which Terraform is provided from AWS
output "name" {
  value = aws_instance.instance1.availability_zone
}

// Saving the publicIP of instance for future usage
resource "null_resource" "null1" {
  provisioner "local-exec" {
    command = "echo ${aws_instance.instance1.public_ip} > publicIP.txt"
  }
  // Using ssh in Terraform
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/home/shashwat/Desktop/AWS/key.pem")
    host        = aws_instance.instance1.public_ip
  }

  // Remotely running commands on instance using provisioner
  provisioner "remote-exec" {
    inline = [

      "sudo yum install httpd git php -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
    ]
  }
}

// Creating EBS volume
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.instance1.availability_zone
  size              = 1

  tags = {
    Name = "terraform-ebs"
  }
}

// Attaching EBS volume to the instance created above 
resource "aws_volume_attachment" "ebs_att" {
  device_name  = "/dev/xvdd"
  volume_id    = aws_ebs_volume.ebs1.id
  instance_id  = aws_instance.instance1.id
  force_detach = true
}

/* Formatting, mounting the EBS volume
and Clearing up the /var/www/html folder to git clone the code
*/
resource "null_resource" "null2" {
  depends_on = [
    aws_volume_attachment.ebs_att,
  ]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/home/shashwat/Desktop/AWS/key.pem")
    host        = aws_instance.instance1.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdd",
      "sudo mount /dev/xvdd /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Shashwat-Joshi/Cloud.git /var/www/html"
    ]
  }
}



# resource "null_resource" "null3" {
#   depends_on = [
#     null_resource.null2,
#   ]
#   provisioner "local-exec" {
#     command = "firefox ${aws_instance.instance1.public_ip}"
#   }
# }





resource "aws_s3_bucket" "bucket" {
  bucket = "shashwat1234567"
  acl    = "private"

  tags = {
    Name        = "terraform-bucket"
    Environment = "Dev"
  }
}

resource "null_resource" "nullgit" {
  depends_on = [
    aws_s3_bucket.bucket,
  ]
  provisioner "local-exec" {
    command = "curl https://raw.githubusercontent.com/Shashwat-Joshi/Cloud/master/image.jpeg > image.jpeg"
  }
}

resource "aws_s3_bucket_object" "object" {
  depends_on = [
    null_resource.nullgit,
  ]
  acl    = "public-read"
  bucket = "shashwat1234567"
  key    = "image.jpeg"
  source = "/home/shashwat/Desktop/terra/create-s3/image.jpeg"
}


// Created Cloud Front for image stored in S3

resource "aws_cloudfront_distribution" "CF1" {
  depends_on = [
    aws_s3_bucket_object.object,
  ]
  origin {
    domain_name = "${aws_s3_bucket.bucket.bucket_domain_name}"
    origin_id   = "S3-Shashwat1234567"
  }

  enabled = true
  comment = "Distribution created via Terraform"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Shashwat1234567"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "terraformCF"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


output "final" {
  value = "${aws_cloudfront_distribution.CF1.domain_name}"
}

