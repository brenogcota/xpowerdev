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
    token="email:jira_token"
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


function pr_jira() {
    echo "Getting Jira card information... ✨"
    ## Encoded to base64
    token="email:jira_token"

    branch=$(git symbolic-ref -q HEAD)
    jira_key="${branch##*/}"
    jira_url="https://project.atlassian.net/rest/api/2/issue/$jira_key"
    jira_response=$(curl -H "Authorization: Basic $token" -s "$jira_url" | jq '. | "### [\(.fields.issuetype.name)] [\(.fields.summary)](https://project.atlassian.net/browse/\(.key)) \n\n \(.fields.description) \n status: \(.fields.status.name)"')

    echo "Updating card $jira_key to Ready for code Review... ✅"

    jira_transition_url="https://project.atlassian.net/rest/api/2/issue/$jira_key/transitions"
    curl -X POST --data '{"transition": { "id": "101" }}' -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Basic $token" -s "$jira_transition_url"

    echo "Opening new Pull Request... 🌱"

    github_repo="${PWD##*/}"
    github_base_branch="master"
    github_head_branch="$(git symbolic-ref -q HEAD)"
    github_title="$(git log --format=%B -n 1 HEAD)"
    title=$(urlencode "$github_title")
    body=$(urlencode "$jira_response")

    open https://github.com/project-Org/"$github_repo"/pull/new/"$github_head_branch"\?title\=$title&body\=$body
}
