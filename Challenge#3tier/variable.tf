variable "region_name" {
  type = string
  default = "us-west-2"
}
variable "ami_id" {
  type = string
  default = "ami-09aca962ca4e0963f"

}
variable "jump_box_instance_type" {
  type = string
  default = "t2.micro"

}
variable "jump_box_keyname" {

  type = string
  default = "task"

}
