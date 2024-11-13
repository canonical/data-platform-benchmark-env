run "setup" {

  command = apply

  module {
    source = "../../vpc/setup"
  }
}