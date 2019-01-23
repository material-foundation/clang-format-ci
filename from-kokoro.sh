#!/bin/bash
#
# Copyright 2018-present The Material Foundation Authors. All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

#  Run clang-format and post suggested changes back to the pull request.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# clang-format releases pulled from https://github.com/material-foundation/clang-format/releases
CLANG_FORMAT_TAG="r345798"
CLANG_FORMAT_SHA="7584ce5ff2633d3a38f41cc41906d328d07b0afdda4adb56edb6fef58042d33a"

# git-clang-format commit pulled from 
# https://github.com/llvm-mirror/clang/blob/master/tools/clang-format/git-clang-format
GIT_CLANG_FORMAT_COMMIT="c510fac5695e904b43d5bf0feee31cc9550f110e"
GIT_CLANG_FORMAT_SHA="1f6cfad79f90ea202dcf2d52a360186341a589cdbfdee05b0e7694f912aa9820"

usage() {
  echo "Usage: $0 <repo>"
  echo
  echo "Will apply clang-format to changes made on the current branch from the merge-base of"
  echo "the target branch. The result will be posted to GitHub as a series of inline comments."
  echo
  echo "Must set the following environment variables to run locally:"
  echo
  echo "GITHUB_API_TOKEN -> Create a token here: https://github.com/settings/tokens."
  echo "                    Must have public_repo scope."
  echo
  echo "KOKORO_GITHUB_PULL_REQUEST_NUMBER=\"###\""
  echo "    The pull request # you want to post the API diff results to."
  echo
  echo "KOKORO_GITHUB_PULL_REQUEST_COMMIT=\"###\""
  echo "    The last commit of the pull request."
  echo
  echo "KOKORO_GITHUB_PULL_REQUEST_TARGET_BRANCH=\"###\""
  echo "    The branch that this pull request will be merged into."
}

REPO="$1"
if [ -z "$REPO" ]; then
  usage
  exit 1
fi

version_as_number() {
  padded_version="${1%.}" # Strip any trailing dots
  # Pad with .0 until we get a M.m.p version string.
  while [ $(grep -o "\." <<< "$padded_version" | wc -l) -lt "2" ]; do
    padded_version=${padded_version}.0
  done
  echo "${padded_version//.}"
}

# xcode-select's the provided xcode version.
# Usage example:
#     select_xcode 9.2.0
select_xcode() {
  desired_version="$1"
  if [ -z "$desired_version" ]; then
    return # No Xcode version to select.
  fi

  xcodes=$(ls /Applications/ | grep "Xcode")
  for xcode_path in $xcodes; do
    xcode_version=$(cat /Applications/$xcode_path/Contents/version.plist \
      | grep "CFBundleShortVersionString" -A1 \
      | grep string \
      | cut -d'>' -f2 \
      | cut -d'<' -f1)
    xcode_version_as_number="$(version_as_number $xcode_version)"

    if [ "$xcode_version_as_number" -ne "$(version_as_number $desired_version)" ]; then
      continue
    fi

    sudo xcode-select --switch /Applications/$xcode_path/Contents/Developer
    xcodebuild -version

    # Resolves the following crash when switching Xcode versions:
    # "Failed to locate a valid instance of CoreSimulatorService in the bootstrap"
    launchctl remove com.apple.CoreSimulator.CoreSimulatorService || true

    break
  done
}

# Will run git clang-format on the branch's changes, reporting a failure if the linter generated any
# stylistic changes.
#
# For local runs, you must set the following environment variables:
#
#   GITHUB_API_TOKEN -> Create a token here: https://github.com/settings/tokens.
#                       Must have public_repo scope.
#   KOKORO_GITHUB_PULL_REQUEST_NUMBER="###" -> The PR # you want to post the API diff results to.
#   KOKORO_GITHUB_PULL_REQUEST_COMMIT="..." -> The PR commit you want to post to.
#
# And install the following tools:
#
# - clang-format
# - git-clang-format
lint_clang_format() {
  repo="$1"
  if [ -z "$GITHUB_API_TOKEN" ]; then
    echo "GITHUB_API_TOKEN must be set to a github token with public_repo scope."
    usage
    exit 1
  fi

  if [ -z "$KOKORO_GITHUB_PULL_REQUEST_NUMBER" ]; then
    echo "KOKORO_GITHUB_PULL_REQUEST_NUMBER must be set to a github pull request number."
    usage
    exit 1
  fi

  if [ -z "$KOKORO_GITHUB_PULL_REQUEST_COMMIT" ]; then
    echo "KOKORO_GITHUB_PULL_REQUEST_COMMIT must be set to a commit."
    usage
    exit 1
  fi

  if [ -z "$KOKORO_GITHUB_PULL_REQUEST_TARGET_BRANCH" ]; then
    echo "$KOKORO_GITHUB_PULL_REQUEST_TARGET_BRANCH must be set to the target branch."
    usage
    exit 1
  fi

  if [ -n "$KOKORO_BUILD_NUMBER" ]; then
    select_xcode "$XCODE_VERSION"

    mkdir bin
    pushd bin >> /dev/null

    # Install clang-format
    echo "Downloading clang-format..."
    curl -Ls "https://github.com/material-foundation/clang-format/releases/download/$CLANG_FORMAT_TAG/clang-format" -o "clang-format"
    if openssl sha -sha256 "clang-format" | grep -q "$CLANG_FORMAT_SHA"; then
      echo "SHAs match. Proceeding."
    else
      echo "clang-format does not match sha. Aborting."
      exit 1
    fi
    chmod +x "clang-format"

    echo "Downloading git-clang-format..."
    # Install git-clang-format
    curl -Ls "https://raw.githubusercontent.com/llvm-mirror/clang/$GIT_CLANG_FORMAT_COMMIT/tools/clang-format/git-clang-format" -o "git-clang-format"
    if openssl sha -sha256 "git-clang-format" | grep -q "$GIT_CLANG_FORMAT_SHA"; then
      echo "SHAs match. Proceeding."
    else
      echo "git-clang-format does not match sha. Aborting."
      exit 1
    fi
    chmod +x "git-clang-format"

    export PATH="$(pwd):$PATH"

    popd >> /dev/null

    # Move into our cloned repo
    cd github/repo
  fi

  if ! git clang-format -h > /dev/null 2> /dev/null; then
    echo
    echo "git clang-format is not configured correctly."
    echo "Please ensure that the git-clang-format command is in your PATH and that it is executable."
    exit 1
  fi

  "$DIR/check-pull-request.sh" \
    --api_token "$GITHUB_API_TOKEN" \
    --repo "$repo" \
    --pr "$KOKORO_GITHUB_PULL_REQUEST_NUMBER" \
    --commit "$KOKORO_GITHUB_PULL_REQUEST_COMMIT" \
    --target_branch "$KOKORO_GITHUB_PULL_REQUEST_TARGET_BRANCH"
}

lint_clang_format "$REPO"
