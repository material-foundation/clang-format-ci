# clang-format-ci

Run clang-format from your CI to automatically suggest style changes in PRs as in-line comments.

## Prerequisites

This script requires `clang-format` and `git clang-format`.

## Usage

This script is intended to be invoked from a continuous integration service that supports running
arbitrary scripts.

### Travis CI

You will likely want to set up your GitHub API token as an
[encrypted environment variable](https://docs.travis-ci.com/user/environment-variables/#defining-encrypted-variables-in-travisyml).
You can then use the following `.travis.yml`, being sure to fill in the TODOs:

```
language: objective-c
sudo: false
env:
  global:
  - LC_CTYPE=en_US.UTF-8
  - LANG=en_US.UTF-8
  matrix:
    secure: # TODO: Configure $GITHUB_TOKEN as a secure environment variable
matrix:
  include:
  - osx_image: xcode10
before_install:
  - brew install clang-format
  - mkdir bin
  - curl -Ls "https://raw.githubusercontent.com/llvm-mirror/clang/c510fac5695e904b43d5bf0feee31cc9550f110e/tools/clang-format/git-clang-format" -o "bin/git-clang-format"
  - chmod +x bin/git-clang-format
  - export PATH="$(pwd)/bin:$PATH"
  - git clone --branch <TODO: version> https://github.com/material-foundation/clang-format-ci.git
script:
  - if [ -n "$TRAVIS_PULL_REQUEST_SLUG" ]; then ./clang-format-ci/check-pull-request.sh --api_token "$GITHUB_TOKEN" --repo "$TRAVIS_PULL_REQUEST_SLUG" --pr "$TRAVIS_PULL_REQUEST" --commit "$TRAVIS_PULL_REQUEST_SHA" --target_branch "$TRAVIS_BRANCH"; fi
```

### Kokoro

You will need to provide both an API token and repo name to the script. Both of these values should
be defined as environment variables in your Kokoro configuration.

Example installation script using a pre-built clang-format binary:

```bash
# Fail on any error.
set -e

REPO="<TODO: Your github repo. E.g. material-foundation/clang-format-ci>"

# The tagged version of https://github.com/material-foundation/clang-format-ci to check out.
# A * wildcard can be used to check out the latest release of a given version.
CLANG_FORMAT_CI_VERSION="v1.*"

CLANG_FORMAT_CI_SRC_DIR=".clang-format-ci-src"

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
  if [ ! -d "$CLANG_FORMAT_CI_SRC_DIR" ]; then
    git clone --recurse-submodules https://github.com/material-foundation/clang-format-ci.git "$CLANG_FORMAT_CI_SRC_DIR"
  fi

  pushd "$CLANG_FORMAT_CI_SRC_DIR"
  git fetch > /dev/null
  TAG=$(git tag --sort=v:refname -l "$CLANG_FORMAT_CI_VERSION" | tail -n1)
  git checkout "$TAG" > /dev/null
  echo "Using clang-format-ci $TAG"
  popd

  .clang-format-ci-src/from-kokoro.sh "$REPO"
}

lint_clang_format
```

