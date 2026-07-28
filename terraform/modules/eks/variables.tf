variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_role_arn" {
  type = string
}

variable "node_group_role_arn" {
  type = string
}

variable "cluster_security_group_id" {
  type = string
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m7i-flex.large"]
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 3
}
