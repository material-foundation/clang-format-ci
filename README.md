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
CLANG_FORMAT_VERSION="r343360"
CLANG_FORMAT_SHA="9d2a3aeaee65f09ae5405dd33812d167fadd48aba712965cdb3238e5d8837255"
GIT_CLANG_FORMAT_VERSION="c510fac5695e904b43d5bf0feee31cc9550f110e"
GIT_CLANG_FORMAT_SHA="1f6cfad79f90ea202dcf2d52a360186341a589cdbfdee05b0e7694f912aa9820"

install_clang_format() {
  mkdir bin
  pushd bin >> /dev/null

  echo "Downloading clang-format..."
  curl -Ls "https://github.com/material-foundation/clang-format/releases/download/$CLANG_FORMAT_VERSION/clang-format" -o "clang-format"
  if openssl sha -sha256 "clang-format" | grep -q "$CLANG_FORMAT_SHA"; then
    echo "SHAs match. Proceeding."
  else
    echo "clang-format does not match sha. Aborting."
    exit 1
  fi
  chmod +x "clang-format"

  echo "Downloading git-clang-format..."
  curl -Ls "https://raw.githubusercontent.com/llvm-mirror/clang/$GIT_CLANG_FORMAT_VERSION/tools/clang-format/git-clang-format" -o "git-clang-format"
  if openssl sha -sha256 "git-clang-format" | grep -q "$GIT_CLANG_FORMAT_SHA"; then
    echo "SHAs match. Proceeding."
  else
    echo "git-clang-format does not match sha. Aborting."
    exit 1
  fi
  chmod +x "git-clang-format"

  export PATH="$(pwd):$PATH"

  popd >> /dev/null
}

if ! git clang-format -h > /dev/null 2> /dev/null; then
  install_clang_format
fi

git clone --branch <TODO: version> https://github.com/material-foundation/clang-format-ci.git
./clang-format-ci/check-pull-request.sh \
  --api_token "$API_TOKEN" \
  --repo "$REPO" \
  --pr "$KOKORO_GITHUB_PULL_REQUEST_NUMBER" \
  --commit "$KOKORO_GITHUB_PULL_REQUEST_COMMIT" \
  --target_branch "$KOKORO_GITHUB_PULL_REQUEST_TARGET_BRANCH"
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
3. Edit the `CLANG_FORMAT_TAG` and `CLANG_FORMAT_SHA` values in [`from-kokoro.sh`](https://github.com/material-foundation/clang-format-ci/blob/develop/from-kokoro.sh#L22-L29) with the tag and sha from the steps above.
4. Send the changes out as a PR.
5. Get the pull request reviewed and merged in to `develop`.
6. Install the [`mdm` toolchain](https://github.com/material-motion/tools#installation). You'll use this to cut the release on clang-format.
7. Cut the release by running `mdm release cut`.
8. Update the changelog notes.
9. Push the release-candidate to GitHub and open an PR for review to stable.
10. Once the PR is LGTM'd, do not merge it via GitHub. Instead, run `mdm release merge <#version number#>`.
11. Run `mdm release publish` to publish the release.
