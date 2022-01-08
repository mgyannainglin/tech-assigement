variable "region" {
  default = "ap-southeast-1"
}
variable "cidr_block" {
  default = "10.0.0.0/16"
}
variable "public_subnet" {
  default = "10.0.1.0/24"
}

variable "private_subnet" {
  default = "10.0.2.0/24"
}

variable "default_subnet" {
  default = "10.0.3.0/24"
}
