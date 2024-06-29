locals {
  default_tags = {
    "Cluster": var.name
  }

  subnet_netbits = 8

  /*
   * Instance
   */

  nat_instance_type = "t3.micro"
}
