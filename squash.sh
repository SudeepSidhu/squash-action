#!/bin/bash

set -e

PR_NUMBER=$(jq -r ".pull_request.number" "$GITHUB_EVENT_PATH")
if [[ "$PR_NUMBER" == "null" ]]; then
	PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
fi
if [[ "$PR_NUMBER" == "null" ]]; then
	echo "Failed to determine PR Number."
	exit 1
fi
echo "Collecting information about PR #$PR_NUMBER of $GITHUB_REPOSITORY..."

if [[ -z "$COMMITTER_TOKEN" ]]; then
	echo "Set the COMMITTER_TOKEN env variable."
	exit 1
fi

URI=https://api.github.com
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $COMMITTER_TOKEN"

pr_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
          "${URI}/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER")

# echo "API response: $pr_resp"

BASE_REPO=$(echo "$pr_resp" | jq -r .base.repo.full_name)
BASE_BRANCH=$(echo "$pr_resp" | jq -r .base.ref)

if [[ "$(echo "$pr_resp" | jq -r .rebaseable)" != "true" ]]; then
	echo "GitHub doesn't think that the PR is rebaseable!"
	echo "API response: $pr_resp"
	exit 1
fi

if [[ -z "$BASE_BRANCH" ]]; then
	echo "Cannot get base branch information for PR #$PR_NUMBER!"
	exit 1
fi

HEAD_REPO=$(echo "$pr_resp" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$pr_resp" | jq -r .head.ref)
COMMIT_NAME=$(echo "$pr_resp" | jq -r .title)

echo "Base branch for PR #$PR_NUMBER is $BASE_BRANCH"

set -o xtrace

git remote set-url origin https://x-access-token:$COMMITTER_TOKEN@github.com/$GITHUB_REPOSITORY.git

git checkout $BASE_BRANCH && git pull
git checkout $HEAD_BRANCH && git pull

git rebase $BASE_BRANCH
git reset --soft $(git rev-parse $BASE_BRANCH) 

git add .
git commit -m "${COMMIT_NAME}"

git push --force-with-lease