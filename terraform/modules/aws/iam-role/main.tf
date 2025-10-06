# 1. Provision the IAM Role
resource "aws_iam_role" "custom_role" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy
  # Prevents deletion if role has active policies (good practice)
  force_detach_policies = true

  # Apply tags to the Role
  tags = var.tags
}

# 2. Attach policies dynamically using a 'for_each' loop
resource "aws_iam_role_policy_attachment" "role_attachments" {
  for_each = toset(var.policy_arns)

  role       = aws_iam_role.custom_role.name
  policy_arn = each.value
}


# ----------------------------------------------------------------------
# 3. Conditional IAM User and Assume Role Policy
# ----------------------------------------------------------------------

# Create IAM User only if var.create_iam_user is true
resource "aws_iam_user" "assumer" {
  count = var.create_iam_user ? 1 : 0
  name  = var.iam_user_name
  # The user's path is set to ensure it's not a root user.
  path = "/service-users/"

  # Apply tags to the Role
  tags = var.tags
}

# Define the policy that allows the user to assume the role created in step 1
data "aws_iam_policy_document" "assume_role_policy_doc" {
  count = var.create_iam_user ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.custom_role.arn] # Reference the role created in this module
  }
}

# Attach the Assume Role Policy as an inline policy to the user
resource "aws_iam_user_policy" "assume_role_policy_attachment" {
  count = var.create_iam_user ? 1 : 0

  name   = "assume-role-${aws_iam_role.custom_role.name}"
  user   = aws_iam_user.assumer[0].name
  policy = data.aws_iam_policy_document.assume_role_policy_doc[0].json
}

# ----------------------------------------------------------------------
# 4. NEW: Conditional Programmatic Access (Access Keys)
# ----------------------------------------------------------------------

resource "aws_iam_access_key" "assumer_keys" {
  # Requires both user creation AND programmatic access to be true
  count = var.create_iam_user && var.create_programmatic_access ? 1 : 0
  user  = aws_iam_user.assumer[0].name
}

# ----------------------------------------------------------------------
# 5. NEW: Conditional Console Access (Login Profile)
# ----------------------------------------------------------------------

resource "aws_iam_user_login_profile" "assumer_login" {
  # Requires both user creation AND console access to be true
  count = var.create_iam_user && var.create_console_access ? 1 : 0
  user  = aws_iam_user.assumer[0].name
  # The password must be a strong random string (Terraform generates this automatically)
  # The password_reset_required flag forces the user to change the password on first login
  pgp_key                 = "" # Set to empty to suppress PGP encryption, but password is still sensitive
  password_reset_required = true
}

# ----------------------------------------------------------------------
# 6. NEW: Conditional PowerUserAccess Assignment
# ----------------------------------------------------------------------

resource "aws_iam_user_policy_attachment" "power_user_policy" {
  # Requires user creation AND power user policy assignment to be true
  count      = var.create_iam_user && var.assign_power_user_policy ? 1 : 0
  user       = aws_iam_user.assumer[0].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
