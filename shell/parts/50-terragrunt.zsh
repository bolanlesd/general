# 50-terragrunt.zsh — terraform / terragrunt aliases and helpers
alias tf="terraform"
alias tg="terragrunt run --tf-forward-stdout"
alias tgp="tg plan"
alias tfp="tf plan -out=tf.plan"
alias tfa="tf apply tf.plan"
alias tgpdiff='tg show -- -json tf.plan > plan-diff.json'

# desc: tgpt <target> — terragrunt plan -target=<target>
tgpt() { terragrunt plan -target="$1"; }

# desc: tgfu <lock-id> — terragrunt force-unlock
tgfu() {
    if [[ -z "$1" ]]; then
        echo "Usage: tgfu <lock-id>"
        return 1
    fi
    terragrunt force-unlock "$1"
}

# desc: cleantgcache — remove every .terra* dir under /hdd/git/live-projects
function cleantgcache() {
  find /hdd/git/live-projects -type d -name ".terra*" -exec rm -rf {} +
}

# desc: tgperm [destroy] — extract AWS perms/ARNs touched by tg apply/destroy
function tgperm() {
  if [ "$1" = "destroy" ]; then
    echo "⚠️ Running Terragrunt Plan with Destroy..."
    terragrunt plan -no-color -destroy

    echo "⚠️ Proceeding with Terragrunt destroy. Confirm when prompted..."
    TF_LOG=trace terragrunt destroy &> log_destroy.log

    echo "🔍 Extracting AWS Permissions and ARNs for Destroy..."
    grep -oE "rpc.method=[^ ]*|rpc.service=[^ ]*|arn:[^ ]*" log_destroy.log | sort | uniq > all_destroy_permissions_arns.txt

    awk '
    {
      if ($1 ~ /^rpc.method=/) {
        method = substr($1, 12)
      } else if ($1 ~ /^rpc.service=/) {
        service = substr($1, 13)
        if (method != "") print method " " service
      } else if ($1 ~ /^arn:/) {
        print $1
      }
    }' all_destroy_permissions_arns.txt > extracted_destroy_permissions_arns.txt

    echo "✅ Destroy permissions and ARNs extracted → extracted_destroy_permissions_arns.txt"
    rm -f all_destroy_permissions_arns.txt

  else
    echo "🛠 Running Terragrunt Plan..."
    terragrunt plan

    read "confirm?Do you want to proceed with Terragrunt apply? (yes/no): "
    if [ "$confirm" != "yes" ]; then
      echo "⛔ Apply process aborted."
      return
    fi

    echo "🛠 Applying Changes with Terragrunt..."
    TF_LOG=trace terragrunt apply &> log_apply.log

    echo "🔍 Extracting AWS Permissions for Apply..."
    grep -oE "rpc.method=[^ ]*|rpc.service=[^ ]*" log_apply.log | sort | uniq > all_apply_permissions.txt

    awk '
    {
      if ($1 ~ /^rpc.method=/) {
        method = substr($1, 12)
      } else if ($1 ~ /^rpc.service=/) {
        service = substr($1, 13)
        if (method != "") print method " " service
      }
    }' all_apply_permissions.txt > extracted_apply_permissions.txt

    echo "✅ Apply permissions extracted → extracted_apply_permissions.txt"
    rm -f all_apply_permissions.txt
  fi

  echo "🎉 Operation completed."
}
