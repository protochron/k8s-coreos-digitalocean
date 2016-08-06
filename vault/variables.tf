variable region {
  description = "Region to launch in"
  default     = "sfo1"
}

variable size {
  description = "Size of the Vault droplet"
  default     = "1gb"
}

variable ssh_keys {
  description = "SSH keys to use"
}

variable image {
  description = "Name of the image to use"
}

variable count {
  description = "Number of vault servers to launch"
  default     = 1
}

variable volume_size {
  description = "Size of the volume to use for storing Vault data"
  default     = "25"
}
