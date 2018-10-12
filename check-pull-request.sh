#!/bin/bash
#
# Copyright 2018-present Material Foundation Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Fail on any error.
set -e

usage() {
  echo "Usage: $0"
  echo
  echo "Runs clang-format against the current pull request's changes."
  echo
  echo "If clang-format suggested changes, the changes are posted to the pull"
  echo "request as line-by-line comments and the script returns a non-zero exit"
  echo "code. Otherwise, the script returns an exit code of 0."
  echo
  echo "If the git clang-format plugin is not installed, then it will be installed."
  echo
  echo "All arguments are required."
  echo
  echo "  --api_token <token>       A GitHub API token with a scope that matches the visibility"
  echo "                            of the repo."
  echo "                            Create a token at https://github.com/settings/tokens/new"
  echo                              
  echo "  --repo <repo>             The GitHub repo to which pull request comments should be"
  echo "                            posted."
  echo "                            E.g. material-components/material-components-ios"
  echo                              
  echo "  --pr <number>             The GitHub number of the pull request to which comments"
  echo "                            should be posted."
  echo                              
  echo "  --commit <SHA>            The pull request's commit to which comments should be posted."
  echo
  echo "  --target_branch <branch>  The pull request's target branch."
  echo "                            E.g. master"
  echo
}

suggest_diff_changes() {
  echo
  echo "clang-format requires the following stylistic changes to be made:"
  echo
  git --no-pager diff

  COMMENT_TMP_PATH=$(mktemp -d)
  COMMENT_TMP_FILE="$COMMENT_TMP_PATH/comment"
  DIFF_TMP_FILE="$COMMENT_TMP_PATH/diff"

  echo "clang-format suggested the following change:" > "$COMMENT_TMP_FILE"
  git --no-pager diff -U0 > "$DIFF_TMP_FILE"

  echo "Posting results to GitHub..."

  pushd github-comment-local >> /dev/null

  swift run github-comment \
    --repo="$REPO" \
    --github_token="$API_TOKEN" \
    --pull_request_number="$PULL_REQUEST" \
    --commit="$KOKORO_GITHUB_PULL_REQUEST_COMMIT" \
    --identifier=clang-format \
    --comment_body="$COMMENT_TMP_FILE" \
    --diff="$DIFF_TMP_FILE"

  cat > "$COMMENT_TMP_FILE" <<EOL
clang-format recommended changes.

Consider installing [git-clang-format](https://github.com/llvm-mirror/clang/blob/master/tools/clang-format/git-clang-format) and running the following command:

\`\`\`bash
git clang-format \$(git merge-base origin/develop HEAD)
\`\`\`
EOL

  swift run github-comment \
    --repo="$REPO" \
    --github_token="$API_TOKEN" \
    --pull_request_number="$PULL_REQUEST" \
    --identifier=clang-format \
    --comment_body="$COMMENT_TMP_FILE"

  popd >> /dev/null

  exit 1
}

delete_comment() {
  pushd github-comment-local >> /dev/null
  # No recommended changes, so delete any existing comment
  swift run github-comment \
    --repo="$REPO" \
    --github_token="$API_TOKEN" \
    --pull_request_number="$PULL_REQUEST" \
    --identifier=clang-format \
    --delete
  popd >> /dev/null
}

main() {
  if ! git diff-index --quiet HEAD --; then
    echo "Changes were already detected on the local branch prior to"
    echo "running git clang-format. Refusing to continue."
    exit 1
  fi

  if [ ! -f "github-comment/README.md" ]; then
    git submodule update --init --recursive
  fi

  if ! git clang-format -h > /dev/null 2> /dev/null; then
    echo "git clang-format is not available. Please install clang-format"
    echo "and git-clang-format and try again."
    exit 1
  fi

  base_sha=$(git merge-base "$TARGET_BRANCH" HEAD)
  echo "Running clang-format on changes from $base_sha to HEAD..."
  git clang-format "$base_sha"

  if ! git diff-index --quiet HEAD --; then
    suggest_diff_changes
  else
    delete_comment
  fi
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
  --api_token)
    API_TOKEN="$2"
    shift
    shift
    ;;
  --repo)
    REPO="$2"
    shift
    shift
    ;;
  --pr)
    PULL_REQUEST="$2"
    shift
    shift
    ;;
  --commit)
    COMMIT="$2"
    shift
    shift
    ;;
  --target_branch)
    TARGET_BRANCH="$2"
    shift
    shift
    ;;
  *)
    POSITIONAL+=("$1")
    shift
    ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ -z "$API_TOKEN" ]; then
  echo "--api_token is required."
  usage
  exit 1
fi

if [ -z "$REPO" ]; then
  echo "--repo is required."
  usage
  exit 1
fi

if [ -z "$PULL_REQUEST" ]; then
  echo "--pr is required."
  usage
  exit 1
fi

if [ -z "$COMMIT" ]; then
  echo "--commit is required."
  usage
  exit 1
fi

if [ -z "$TARGET_BRANCH" ]; then
  echo "--target_branch is required."
  usage
  exit 1
fi

main
