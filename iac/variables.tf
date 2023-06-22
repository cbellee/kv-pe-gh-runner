variable "prefix" {
    type = string
    default = "cbellee"
}

variable "object_id" {
    type = string
    default = "963f10-818b-406d-a2f6-6e758d86e259"
}

variable "ssh_public_key" {
    type = string
    default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCKEnblRrHUsUf2zEhDC4YrXVDTf6Vj3eZhfIT22og0zo2hdpfUizcDZ+i0J4Bieh9zkcsGMZtMkBseMVVa5tLSNi7sAg79a8Bap5RmxMDgx53ZCrJtTC3Li4e/3xwoCjnl5ulvHs6u863G84o8zgFqLgedKHBmJxsdPw5ykLSmQ4K6Qk7VVll6YdSab7R6NIwW5dX7aP2paD8KRUqcZ1xlArNhHiUT3bWaFNRRUOsFLCxk2xyoXeu+kC9HM2lAztIbUkBQ+xFYIPts8yPJggb4WF6Iz0uENJ25lUGen4svy39ZkqcK0ZfgsKZpaJf/+0wUbjqW2tlAMczbTRsKr8r cbellee@CB-SBOOK-1809"
}

variable admin_username {
    type = string
    default = "localadmin"
}

variable "subscription_id" {
    default  = "b2375b5f-8dab-4436-b87c-32bc7fdce5d0"
    type = string
}

variable "tenant_id" {
    type = string
    default = "3d49be6f-6e38-404b-bbd4-f61c1a2d25bf"    
}

variable "location" {
    type = string
    default = "australiaeast"
}

variable "resource-group-name" {
    type = string
    default = "tf-kv-pe-rg"
}

variable "tags" {
    type = map(string)
    default = {
      "environment" = "dev"
      "tier"        = 0
    }
}