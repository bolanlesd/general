export VISUAL=vim
export EDITOR="$VISUAL"

# Function to get current git branch
git_branch() {
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ ! -z "$branch" ]; then
        echo "($branch)"
    fi
}

# Customize PS1 to include git_branch with colors
export PS1="\[\e[33m\]\A\[\e[m\] \w \[\e[32m\]\$(git_branch)\[\e[m\] $ "

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Source bash completion for bash >= 4.2
if [ -f /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
    . /opt/homebrew/etc/profile.d/bash_completion.sh
fi

# Add kubectl completion
if command -v kubectl &>/dev/null; then
    source <(kubectl completion bash)
fi

#alias ms="minikube start --extra-config=controller-manager.HorizontalPodAutoscalerUseRESTClients=true; minikube addons enable ingress"
alias ms="minikube start; minikube addons enable ingress"

alias getmyip="curl ifconfig.me"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gdm="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit master.."
alias gs="git status"
alias gat="git ls-files --modified | xargs git add"
alias gaa="git add -u"
alias gb="git branch | grep \"*\" | cut -d ' ' -f2"
function gco() {
  local BRANCH=$(gb)
  local FUNCTION=$1
  local COMMENT="${@:2}"
  git commit -m "$FUNCTION: $BRANCH: $COMMENT"
}

alias tf="terraform"
alias tg="terragrunt run --tf-forward-stdout"
alias tgp="tg plan"
tgpt() {
    terragrunt plan -target="$1"
}

alias tfp="tf plan -out=tf.plan"
alias tfa="tf apply tf.plan"
alias rb=". ~/.bashrc; . .bash_profile"
alias tgo="tmux new -s seun"

alias fn="find -name $1"

alias lsd="ls -d */ | xargs du -chs | grep -v total"

alias gr="cd $(git rev-parse --show-toplevel)"
#alias gr="echo $(git rev-parse --show-toplevel)"

alias ocp="xclip -i -sel c"

alias choco="echo \"scripts/windows/iis/setup.ps1:Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))\""

alias rts="find . -not -path '*/\\.*' | xargs -I {} sed -i 's/[[:space:]]*$//' {}"

function ppc() {
  column -t -s, "$1"
}

function lsak() {
  for i in $(aws iam list-users --query 'Users[*].UserName' --output text)
    do aws iam list-access-keys --user-name $i --query 'AccessKeyMetadata[*].[UserName, AccessKeyId]' --output text
  done
}

function hc() {
  COMMAND=$(history | tail -n $1 | head -n1 | awk '{$1="";print substr($0,2)}')
}

function gg() {
  local TEXT="${@:1}"
  git grep -i -n "$TEXT" -- `git rev-parse --show-toplevel`
}

function insid() {
  aws ec2 describe-instances --instance-id $1 --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]' --output text
}

#aws ec2 describe-instances  --query 'Reservations[*].Instances[*].[InstanceId,Placement.AvailabilityZone,InstanceType,Platform,LaunchTime,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]' --output text --filters 'Name=hibernation-options.configured,Values=true'

function instag() {
  if [ -z $1 ]
    then aws ec2 describe-instances  --query 'Reservations[*].Instances[*].[InstanceId,Placement.AvailabilityZone,InstanceType,Platform,LaunchTime,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]' --output text
  elif [ -z $2 ]
    then aws ec2 describe-instances  --query 'Reservations[*].Instances[*].[InstanceId,Placement.AvailabilityZone,InstanceType,Platform,LaunchTime,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]' --output text | grep -i $1
  else
    local TAG="${2:-Name}"
    local VALUE="${1:-*}"
    aws ec2 describe-instances --filter "Name=tag:$TAG,Values=$VALUE"  --query 'Reservations[*].Instances[*].[InstanceId,Placement.AvailabilityZone,InstanceType,Platform,LaunchTime,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]' --output text
  fi
}

function inssec() {
  local INSID=$1
  echo "Instance $INSID has security groups:"

  # Retrieve and print security group IDs
  local SGIDS=$(aws ec2 describe-instances --instance-ids "$INSID" --query 'Reservations[*].Instances[*].NetworkInterfaces[*].Groups[*].GroupId' --output text)
  echo "$SGIDS"

  # Iterate over each security group ID
  for SGID in $SGIDS; do
    echo "Rules for $SGID:"
    
    # Retrieve security group rules, filtering out egress rules
    aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$SGID" --query 'SecurityGroupRules[?IsEgress==`false`].[FromPort,ToPort,CidrIpv4,Description]' --output text | \
      awk 'BEGIN {print "FromPort ToPort CidrIpv4 Description"} {print $1, $2, $3, $4}' | \
      column -t
    echo
  done
}



alias ssm="aws ssm start-session --target $i"

function sst() {
  IFS=$'\n'
  echo "logging you into these instances"
  NAME=$1
  instag $NAME | grep running
  INSID=$(instag $NAME | grep running | cut -f1)
  for i in $(instag $NAME | grep running); do
    echo "logging you into $i"
    ssm $(echo $i | cut -f1)
   done
}

function lssec() {
  aws secretsmanager list-secrets --query 'SecretList[].[Name,ARN]' --output text | column -t
}

function getsec() {
  for i in $(aws secretsmanager list-secrets --query 'SecretList[].[Name,ARN]' --output text | column -t | grep $1 | awk '{print $2}'); do
    echo Secret: $(echo $i | sed 's/.*://g')
    aws secretsmanager get-secret-value --secret-id $i --query 'SecretString' --output text | sed 's/\\//g' | jq | grep -v '{\|}' | sed 's/"//g;s/://g;s/,//g;s/  //g' | column -t -s ' '
    echo
  done
}

function tgf() {
  for i in $(find -name "terragrunt*" | grep -v terragrunt-cache)
    do TEMP=$(echo $i | sed 's/hcl/tf/g')
    mv $i $TEMP
    terraform fmt $TEMP
    mv $TEMP $i
  done
}

function tff() {
  for i in $(find -name "*.tf" | grep -v terragrunt-cache)
    do terraform fmt $i
  done
}

function tcp() {
  if [ "$(uname -s)" = "Linux" ]; then
    tmux show-buffer | xclip -sel clip -i
  else
    tmux show-buffer | pbcopy
  fi
}

alias wp="kubectl get po --watch | grep $1"

alias ep="kubectl exec -it $1 /bin/sh"
alias gwr="for i in \$(git ls-files | grep \"tf$\|hcl$\|py$\|json$\|groovy$\|ts$\"); do sed -i 's/[[:space:]]\+$//' \$i; done"
alias t2s="for i in \$(git ls-files | grep \"tf$\|hcl$\"); do sed -i 's/\\t/  /g' \$i; done"
alias gba="git log | grep Author | sort | uniq -c"

# function fixb() {
#   gwr
#   gaa
#   gco fix removing trailing spaces
#   t2s
#   gaa
#   gco fix converting tabs to spaces
#   terraform fmt --recursive
#   terragrunt hclfmt --recursive
#   gaa
#   gco fix aligning terragrunt and teraform files
# }

function awsp() {
  ENV="${1:-default}"
  export AWS_PROFILE="${1:-default}"
}

function fmtbranch() {
  for i in $(find -name "*.hcl" | sed 's/\.hcl//'); do
    mv $i.hcl $i.tf
    terraform fmt $i.tf
    mv $i.tf
    $i.hcl
  done
}

function taws() {
  if [ !  -z "$1" ]
  then
    export AWS_ACCESS_KEY_ID=$1
    export AWS_SECRET_ACCESS_KEY=$2
  else
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
  fi
}

function tflog() {
  export TF_LOG=DEBUG
  export TF_LOG_PATH=$(pwd)/log.log
}

function reni() {
  IP=$(dig +short $1 | tail -n1)
  aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].[NetworkInterfaceId,PrivateIpAddresses[*].PrivateIpAddress]' --output text | grep -B1 $IP | grep eni
}

function inspw() {
  ID=$1
  KEYPAIR=$2
  aws ec2 get-password-data --instance-id $ID --priv-launch-key $KEYPAIR
}

function sga () {
  aws ec2 describe-network-interfaces --filter Name=group-id,Values="${1:-*}" --query 'NetworkInterfaces[*].Attachment'
}

alias l53="aws route53 list-hosted-zones --query 'HostedZones[*].[Id,Name]' --output text | sed 's_.*/__g'"

alias shzone="aws route53 list-resource-record-sets --hosted-zone-id $1 --query 'ResourceRecordSets[*].[Type,Name,AliasTarget.DNSName]' --output text | column --table"

function s53() {
  local ZONES=$(l53 | grep $1 | cut -f1)
  for i in $(echo $ZONES)
  do l53 | grep $i
    aws route53 list-resource-record-sets --hosted-zone-id $i --query 'ResourceRecordSets[*].[Type,Name,AliasTarget.DNSName]' --output text | grep -v "NS\|SOA" | sort -u | column --table
  done
}

function r53() {
for i in $(l53 | cut -f1)
  do echo "Hosted Zone: $(aws route53 get-hosted-zone --id $i --query 'HostedZone.[Id,Name]' --output text | sed 's_.*/__g')"
  s53 $i
done | grep "Hosted Zone\|$1" | grep -B1 "$1"
}

function gc() {
  #meant for gopro mp4 footage, this should shrink it to a smaller size
  mkdir converted
  for i in $(ls *.MP4); do NAME=$(echo $i | cut -d '.' -f1); ffmpeg -i $i -vcodec libx265 -crf 28 converted/$NAME-converted.mp4; done
}

function aaws() {
  local COMMAND="$1"
  echo $COMMAND
  for i in $(grep "\[" $HOME/.aws/credentials | sed 's/\[//g;s/\]//g' | grep -v 'assume-')
    do echo "account $i"
    awsp $i
    $COMMAND
  done
}

#neovim magics
# now you can copy to clipboard with '+y'
#set clipboard+=unnamedplus
source <(kubectl completion bash)
complete -C aws_completer aws

alias synctime="sudo apt install ntpdate && sudo ntpdate pool.ntp.org"
alias editgeneral="code /hdd/git/general/ -r"

function seesize() {
  df -h "$@"
}

function seesizes() {
  du -sh "$1"* | sort -rh
}

function cleantgcache() {
  find /hdd/git/live-projects -type d -name ".terra*" -exec rm -rf {} +
}

function create_pr() {
    # Ensure necessary commands are available
    if ! command -v az &>/dev/null || ! command -v jq &>/dev/null; then
        echo "Required command(s) 'az' or 'jq' not found."
        return 1
    fi

    # Check if the current directory is a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        echo "This is not a git repository."
        return 1
    fi

    local REPO_NAME=$(basename "$(pwd)")
    local PR_TEMPLATE_PATH=".azuredevops/pull_request_template.md"

    if [ ! -f "$PR_TEMPLATE_PATH" ]; then
        echo "PR template file not found."
        return 1
    fi

    local PR_DESCRIPTION=$(cat "$PR_TEMPLATE_PATH")
    local BRANCH_NAME=$(git branch --show-current)
    local TICKET_ID=${1:-$BRANCH_NAME}
    local LAST_COMMIT_MESSAGE=$(git log -1 --pretty=%B)
    local PR_TITLE="$LAST_COMMIT_MESSAGE"
    local PR_OUTPUT=$(az repos pr create --auto-complete false --repository "$REPO_NAME" --source-branch "$BRANCH_NAME" --target-branch master --description "$PR_DESCRIPTION" --title "$PR_TITLE" --work-items "$TICKET_ID")

    if [ $? -eq 0 ]; then
        local PR_URL=$(echo "$PR_OUTPUT" | jq -r '.repository.webUrl + "/pullrequest/" + (.pullRequestId | tostring)')
        echo "Pull Request created: $PR_URL"
    else
        echo "Failed to create Pull Request"
        return 1
    fi
}

# Export the function if needed
export -f create_pr

alias updateall="sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo snap refresh"

tgperm() {
    # Check if the argument is 'destroy'
    if [ "$1" == "destroy" ]; then
        echo "Running Terragrunt Plan with Destroy..."
        terragrunt plan -no-color -destroy

        echo "Proceeding with Terragrunt destroy. Confirm when prompted by Terraform..."
        TF_LOG=trace terragrunt destroy &> log_destroy.log

        echo "Extracting AWS Permissions and ARNs for Destroy..."
        
        # Capture permissions and any ARNs
        grep -o "rpc.method=[^ ]* \(rpc.service=[^ ]*\)\?\|arn:[^ ]*" log_destroy.log | sort | uniq > all_destroy_permissions_arns.txt

        awk -F" " '{
            if ($1 ~ /^rpc.method=/) {
                method = substr($1, 12); # Strip "rpc.method=" prefix
                service = (NF >= 2 && $2 ~ /^rpc.service=/) ? substr($2, 13) : ""; # Strip "rpc.service=" prefix if present
                if (service != "") {
                    combined[method] = method " " service;
                } else if (!(method in combined)) {
                    combined[method] = method;
                }
            } else if ($1 ~ /^arn:/) {
                # Clean up any special characters in ARNs
                clean_arn = gensub(/[^a-zA-Z0-9:_\/-]/, "", "g", $1);
                arns[clean_arn] = clean_arn; # Store unique ARNs
            }
        }
        END {
            for (entry in combined) {
                print combined[entry];
            }
            for (arn in arns) {
                print arn;
            }
        }' all_destroy_permissions_arns.txt > extracted_destroy_permissions_arns.txt

        echo "Destroy permissions and ARNs extracted to extracted_destroy_permissions_arns.txt"

        rm -f all_destroy_permissions_arns.txt

    else
        echo "Running Terragrunt Plan..."
        terragrunt plan

        # Prompt for user confirmation to continue with apply
        read -p "Do you want to proceed with Terragrunt apply? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Apply process aborted."
            return
        fi

        echo "Applying Changes with Terragrunt..."
        TF_LOG=trace terragrunt apply &> log_apply.log

        echo "Extracting AWS Permissions for Apply..."
        grep -o "rpc.method=[^ ]* \(rpc.service=[^ ]*\)\?" log_apply.log | sort | uniq > all_apply_permissions.txt

        awk -F" " '{
            method = substr($1, 12); # Strip "rpc.method=" prefix
            service = (NF == 2) ? substr($2, 13) : ""; # Strip "rpc.service=" prefix if present
            if (service != "") {
                combined[method] = method " " service;
            } else if (!(method in combined)) {
                combined[method] = method;
            }
        }
        END {
            for (entry in combined) {
                print combined[entry];
            }
        }' all_apply_permissions.txt > extracted_apply_permissions.txt

        echo "Apply permissions extracted to extracted_apply_permissions.txt"

        rm -f all_apply_permissions.txt
    fi

    echo "Operation completed successfully."
}

# Ensure Git completion script is downloaded and sourced
GIT_COMPLETION_SCRIPT=~/.git-completion.bash
if [ ! -f "$GIT_COMPLETION_SCRIPT" ]; then
  echo "Git completion script not found, downloading..."
  curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o "$GIT_COMPLETION_SCRIPT"
  chmod +x "$GIT_COMPLETION_SCRIPT"
fi

if [ -f "$GIT_COMPLETION_SCRIPT" ]; then
  . "$GIT_COMPLETION_SCRIPT"
else
  echo "Failed to source Git completion script."
fi

export PATH=$PATH:/opt/homebrew/bin


alias pcra="pre-commit run -a"

# Function to create and activate the virtual environment
create_venv() {
    echo "Creating virtual environment..."
    python3 -m venv myenv
    echo "Activating virtual environment..."
    source myenv/bin/activate
    echo "Installing dependencies..."
    pip3 install requests packaging
}

# Function to deactivate and remove the virtual environment
cleanup_venv() {
    echo "Cleaning up..."
    deactivate
    rm -rf myenv
    echo "Process completed."
}


# Function to query Route 53 for records containing a specific word
function search_r53() {
    local search_word=$1

    if [ -z "$search_word" ]; then
        echo "Usage: search_r53 <search_word>"
        return 1
    fi

    # List all hosted zones
    local hosted_zones
    hosted_zones=$(aws route53 list-hosted-zones --query "HostedZones[*].Id" --output text)

    # Loop through each hosted zone
    for zone in $hosted_zones; do
        local zone_id
        zone_id=$(echo $zone | cut -d'/' -f3)  # Extract the Zone ID
        echo "Querying hosted zone: $zone_id"

        # List all records in the current hosted zone
        local records
        records=$(aws route53 list-resource-record-sets --hosted-zone-id $zone_id)

        # Filter records containing the search word
        local matching_records
        matching_records=$(echo $records | jq --arg search_word "$search_word" '.ResourceRecordSets[] | select(.Name | contains($search_word))')

        # Check if there are any matching records
        if [ -n "$matching_records" ]; then
            echo "Matching records in zone $zone_id:"
            echo "$matching_records"
            echo "--------------------------------"
        fi
    done
}

# Alias to retag an ECR image
alias ecr-retag-image='f() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: ecr-retag-image <repository-name> <source-tag> <target-tag>"
        return 1
    fi

    local repository="$1"
    local source_tag="$2"
    local target_tag="$3"

    # Retrieve the image manifest for the source tag
    local manifest
    manifest=$(aws ecr batch-get-image \
        --repository-name "$repository" \
        --image-ids imageTag="$source_tag" \
        --query 'images[].imageManifest' \
        --output text)

    if [ -z "$manifest" ]; then
        echo "Error: Unable to retrieve manifest for tag '$source_tag' in repository '$repository'."
        return 1
    fi

    # Push the image manifest with the new tag
    aws ecr put-image \
        --repository-name "$repository" \
        --image-tag "$target_tag" \
        --image-manifest "$manifest"

    if [ "$?" -eq 0 ]; then
        echo "Successfully retagged '$source_tag' as '$target_tag' in repository '$repository'."
    else
        echo "Error: Failed to retag image."
        return 1
    fi
}; f'

function tp_start() {
  local app=$1

  # Check if app variable is empty
  if [ -z "$app" ]; then
    echo "Error: No environment specified. Please provide the application name."
    return 1
  fi

  # Run the sequence of commands
  echo "Logging out of current session..."
  tsh apps logout

  echo "Logging in with Azure AD..."
  tsh login --proxy=youlend.teleport.sh:443 --auth=ad

  echo "Logging into AWS app '$app'..."
  tsh apps login "$app" --aws-role sudo_admin

  echo "Starting AWS proxy for '$app'..."
  tsh proxy aws --app "$app"
}