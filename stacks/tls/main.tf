variable "model_name" {
    type = string
}

variable "opensearch_nodes" {
    type = object({
      instance_type = string
      spaces = map(string)
      root-disk = string
      data-disk = string
      base = string
      channel = string
      count = number
    })
}

// --------------------------------------------------------------------------------------
//           OpenSearch Deployment
// --------------------------------------------------------------------------------------

resource "juju_machine" "opensearch_nodes" {
  for_each = var.opensearch_nodes.count

  model = var.model_name
  constraints = {
    "instance-type" = each.value.instance_type
    "root-disk" = each.value.root-disk
    "data-disk" = each.value.data-disk
    "base" = each.value.base
    "spaces" = each.value.spaces
  }
}