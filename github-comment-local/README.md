# github-comment

This is a command line tool for posting comments to GitHub pull requests.

## Building

This tool uses the Swift package manager.

To build the tool, run:

    swift build

To generate an Xcode project, run:

    swift package generate-xcodeproj

## Usage

All features of this tool will require that you have a GitHub API token with either public_repo
or private_repo access, depending on the visibility of the repositories you're interacting with.

### Parameters

    All commands
    --repo=...                 The repo to which comments should be made.
                               Example: material-components/material-components-ios
    --github_token=...         A GitHub token with either public_repo or private_repo scope.
    --pull_request_number=...  The number of the pull request to which comments should be made.
                               Example: 1234
    --identifier=...           A unique identifier that is used when deleting comments.
                               Example: clang-format
    
    Posting comments
    --comment_body=...         A path to a file containing the body of the comment to be posted.
    
    Deleting comments
    --delete                   Indicates that a comment with the given identifier should be deleted.
    
    Diff comments
    --commit=...               The most recent commit on the pull request.
    --diff=...                 A path to a file containing the suggested diff based from the most
                               recent commit.

### To post a comment to a public pull request

This will post a comment as the user associated with the `github_token`.

    swift run github-comment \
      --repo="$REPO" \
      --github_token="$GITHUB_API_TOKEN" \
      --pull_request_number="$PULL_REQUEST_NUMBER" \
      --identifier="$UNIQUE_COMMENT_IDENTIFIER" \
      --comment_body="$COMMENT_FILE"

### To delete a comment from a public pull request

This will delete a comment with the given iidentifier made by the user associated with the
`github_token`.

    swift run github-comment \
      --repo="$REPO" \
      --github_token="$GITHUB_API_TOKEN" \
      --pull_request_number="$PULL_REQUEST_NUMBER" \
      --identifier="$UNIQUE_COMMENT_IDENTIFIER" \
      --delete

### To post a suggested diff as line-by-line comments

This will post a series of in-line comments to the pull request's diff with the suggested changes.
Each comment will consist of the contents of `comment_body` plus the diff hunk for the affected
lines.

This command requires that you make changes to the pull request's most recent commit and generate
a diff with zero context lines. Once you've made the desired changes to the pull request's code
— e.g. by running clang-format — you can generate a zero-context diff like so:

    git --no-pager diff -U0 > "$DIFF_FILE"

You can then suggest this diff as line-by-line comments to the pull request like so:

    swift run github-comment \
      --repo="$REPO" \
      --github_token="$GITHUB_API_TOKEN" \
      --pull_request_number="$PULL_REQUEST_NUMBER" \
      --identifier="$UNIQUE_COMMENT_IDENTIFIER" \
      --comment_body="$COMMENT_TMP_FILE" \
      --commit="$PULL_REQUEST_COMMIT" \
      --diff="$DIFF_FILE"
