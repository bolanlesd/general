# 40-aws.zsh — AWS profile + identity helpers
alias awsid="aws sts get-caller-identity"

# desc: awsp [profile] — switch AWS_PROFILE (default: "default")
function awsp() {
  local ENV="${1:-default}"
  export AWS_PROFILE="$ENV"
  echo "Switched to AWS_PROFILE=$AWS_PROFILE"
}
