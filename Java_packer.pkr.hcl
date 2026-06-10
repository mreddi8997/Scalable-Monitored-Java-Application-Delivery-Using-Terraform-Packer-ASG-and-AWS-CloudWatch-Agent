packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# 1. Define the base environment to build upon
source "amazon-ebs" "spring_boot_app" {
  ami_name      = "java-app-golden-image-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = "t3.small"
  region        = "us-east-2" # Swap with your active region if different

  # Find the latest official Ubuntu 22.04 LTS image as our base
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical's official AWS Owner ID
  }
  
  ssh_username = "ubuntu"
}

# 2. Define the setup steps inside the machine
build {
  name = "java-app-packer"
  sources = [
    "source.amazon-ebs.spring_boot_app"
  ]

  # Step A: Copy the compiled JAR file from the target directory onto the instance
  provisioner "file" {
    source      = "target/spring-boot-web.jar" # Verify your actual target filename!
    destination = "/home/ubuntu/app.jar"
  }

  # Step B: Install Java runtime on the base OS and configure the app to run on boot
  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y openjdk-17-jre-headless",
      
      # Create a background systemd service for your app
      "echo '[Unit]', | sudo tee /etc/systemd/system/java-app.service",
      "echo 'Description=Java Spring Boot Application' | sudo tee -a /etc/systemd/system/java-app.service",
      "echo '[Service]' | sudo tee -a /etc/systemd/system/java-app.service",
      "echo 'ExecStart=/usr/bin/java -jar /home/ubuntu/app.jar' | sudo tee -a /etc/systemd/system/java-app.service",
      "echo 'SuccessExitStatus=143' | sudo tee -a /etc/systemd/system/java-app.service",
      "echo 'TimeoutStopSec=10' | sudo tee -a /etc/systemd/system/java-app.service",
      "echo 'Restart=on-failure' | sudo tee -a /etc/systemd/system/java-app.service",
      "echo '[Install]' | sudo tee -a /etc/systemd/system/java-app.service",
      "echo 'WantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/java-app.service",
      
      # Enable the service so it kicks off automatically in your Auto Scaling Group later
      "sudo systemctl daemon-reload",
      "sudo systemctl enable java-app.service"
    ]
  }
}