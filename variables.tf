
# Defining Public Key
variable "public_key" {
  default = "tests.pub"
}
# Defining Private Key
variable "private_key" {
  default = "tests.pem"
}
# Definign Key Name for connection
variable "key_name" {
 default = "tests"
}
# Defining CIDR Block for VPC
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
# Defining CIDR Block for Subnet
variable "subnet-1_cidr" {
  default = "10.0.1.0/24"
}
# Defining CIDR Block for 2d Subnet
variable "subnet-2_cidr" {
  default = "10.0.2.0/24"
}
