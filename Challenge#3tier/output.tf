output "jump_box_ip" {
  value = ["${aws_instance.jump_box.public_ip}"]
}


output "elb_dns_name" {
  value = "${aws_elb.web.dns_name}"
}
