function urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for ((pos = 0; pos < strlen; pos++)); do
        c="${string:$pos:1}"
        case "$c" in
        [-_.~a-zA-Z0-9])
            o="${c}"
            ;;
        *)
            printf -v o '%%%02x' "'$c"
            ;;
        esac
        encoded+="$o"
    done
    echo "$encoded"
}

function start_dev() {
    # Check if Jira ticket key is provided
    if [ -z "$1" ]; then
        echo "Please provide a Jira ticket key as an argument."
        return 1
    fi

    echo "Starting development... 🚀"

    ## Encoded to base64
    token="email:token"
    jira_key="$1"
    
    echo "Creating a new branch..."
    # Create a branch in local Git repository
    github_head_branch="feature/$jira_key"
    git fetch
    git pull origin HEAD --no-rebase
    git checkout -b "$github_head_branch"    
    
    echo "Updating card $jira_key to In Development..."

    jira_transition_url="https://project.atlassian.net/rest/api/2/issue/$jira_key/transitions"
    curl -X POST --data '{"transition": { "id": "261" }}' -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Basic $token" -s "$jira_transition_url"

   echo "Done. ✨"
}

function jira_status() {
  token="email:token"

  echo "Getting Jira status.. ♻️"
  branch=$(git symbolic-ref -q HEAD)
  jira_key="${branch##*/}"
  jira_url="https://project.atlassian.net/rest/api/2/issue/$jira_key/transitions"

  jira_response=$(curl -H "Authorization: Basic $token" -s "$jira_url" | jq -r '.transitions[] | @base64')

  for transition in $(echo "$jira_response"); do
    # Decode the base64 encoded JSON object
    _jq() {
        echo ${transition} | base64 --decode | jq -r ${1}
    }

    # Extract the transition ID and name
    transition_id=$(_jq '.id')
    transition_name=$(_jq '.name')

    # Print or use the transition ID and name as needed
    echo "Transition ID: $transition_id, Name: $transition_name"
  done
}

function jira_transition() {
    ## Encoded to base64
    token=""

    branch=$(git symbolic-ref -q HEAD)
    jira_key="${branch##*/}"

    echo "Updating card $jira_key ... ✅"

    jira_transition_url="https://project.atlassian.net/rest/api/2/issue/$jira_key/transitions"
    curl -X POST --data '{"transition": { "id": "'$transition_id'" }}' -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Basic $token" -s "$jira_transition_url"

    echo "Done. ✨"
}

function pr_jira() {
    transition_id="$1"
    if [ -z "$1" ]; then
        echo "Transition id not provided, select one 🚨"
        jira_status
        read input
        transition_id=$(echo $input)
    fi
    echo "Getting Jira card information... ✨"
    ## Encoded to base64
    token="email:token"

    branch=$(git symbolic-ref -q HEAD)
    jira_key="${branch##*/}"
    jira_url="https://project.atlassian.net/rest/api/2/issue/$jira_key"
    jira_response=$(curl -H "Authorization: Basic $token" -s "$jira_url" | jq '. | "### [\(.fields.issuetype.name)] [\(.fields.summary)](https://project.atlassian.net/browse/\(.key)) \n\n \(.fields.description) \n status: \(.fields.status.name)"')

    jira_transition
    
    echo "Opening new Pull Request... 🌱"

    github_repo="${PWD##*/}"
    github_base_branch="master"
    github_head_branch="$(git symbolic-ref -q HEAD)"
    github_title="$(git log --format=%B -n 1 HEAD)"
    title=$(urlencode "$github_title")
    body=$(urlencode "$jira_response")
    limited_string=$(printf "%.240s" "$body" | LC_CTYPE=C tr -dc '\000-\177' | cut -c -262144)

    echo "Done. ✨"

    open https://github.com/project-Org/"$github_repo"/pull/new/"$github_head_branch"\?title\=$title&body\=$limited_string
}
