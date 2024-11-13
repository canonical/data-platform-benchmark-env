// --------------------------------------------------------------------------------------
//      Contains all the common variables. Modules may define their own vars as well
// --------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------
//      Varibles that must be set
// --------------------------------------------------------------------------------------

variable "ACCESS_KEY_ID" {
    type      = string
    sensitive = true
}

variable "SECRET_KEY" {
    type      = string
    sensitive = true
}

variable "region" {
    type = string
}