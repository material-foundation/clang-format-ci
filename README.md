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

## How to update the clang-format-ci version

First: build and release the clang-format version.

1. Fork and clone https://github.com/material-foundation/clang-format onto a mac machine.
2. Run `clang-format --version` to identify your local version of clang-format.
3. Edit the [`REV`](https://github.com/material-foundation/clang-format/blob/develop/build.sh#L20) variable in `build.sh` with the revision number you'd like to build.
4. Run `build.sh`.
5. While the build is running, create a pull request with the changes to build.sh.
6. Get the pull request reviewed and merged in to `develop`.
7. Once the local build has finished (takes 1hr+), create a draft release named after the clang-format revision number.
8. Upload the clang-format binary to the release.
9. Include the generated SHA value in the release notes.
10. Publish the release.

Second: create a new clang-format-ci release.

1. Fork and clone https://github.com/material-foundation/clang-format-ci onto a mac machine.
2. Edit the `CLANG_FORMAT_TAG` and `CLANG_FORMAT_SHA` values in [`from-kokoro.sh`](https://github.com/material-foundation/clang-format-ci/blob/develop/from-kokoro.sh#L22-L29) with the tag and sha from the steps above.
3. Send the changes out as a PR.
4. Get the pull request reviewed and merged in to `develop`.
5. Install the [`mdm` toolchain](https://github.com/material-motion/tools#installation). You'll use this to cut the release on clang-format.
6. Cut the release by running `mdm release cut`.
7. Update the changelog notes.
8. Push the release-candidate to GitHub and open an PR for review to stable.
9. Once the PR is LGTM'd, do not merge it via GitHub. Instead, run `mdm release merge <#version number#>`.
11. Run `mdm release publish` to publish the release.
