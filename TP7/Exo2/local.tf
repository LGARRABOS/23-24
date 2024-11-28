locals {
  user = "lgarrabos"                  # Change this to your own username
  tp   = basename(abspath(path.root)) # Get the name of the current directory
  name = "${local.user}-${local.tp}"  # Concatenate the username and the directory name
  tags = {                            # Define a map of tags to apply to all resources
    Name  = local.name
    Owner = local.user
  }
}

resource "aws_key_pair" "bastion" {
  key_name   = "${local.name}-bastion"
  public_key = file("ssh/bastion.pub")
}

resource "aws_key_pair" "nextcloud" {
  key_name   = "${local.name}-nextcloud"
  public_key = file("ssh/nextcloud.pub")
}