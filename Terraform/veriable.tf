variable "aws_region" {
 default = "us-east-1"
}

variable "ami_id" {
 default = "ami-053b0d53c279acc90"
}

variable "instance_type" {
 default= "t2.micro"
}

variable "key_name" {
 type = string
}

variable "public_key_path" {
 type = string

}
