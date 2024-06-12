#!/bin/bash

# Helper script to release the Go SDK

set -e

# Read the contents of the files into variables
version=$(<internal/version)
build=$(<internal/version-build)
changelog=$(<internal/changelogs/"${version}"-"${build}")

# Check if Github CLI is installed
if ! command -v gh &> /dev/null; then
	echo "gh is not installed";\
	exit 1;\
fi

# Ensure GITHUB_TOKEN env var is set
if [ -z "${GITHUB_TOKEN}" ]; then
  echo "GITHUB_TOKEN environment variable is not set."
  exit 1
fi

git tag -a -s  "v${version}" -m "${version}"

# Get Current Branch Name
branch="$(git rev-parse --abbrev-ref HEAD)"

# if on main, then stash changes and create RC branch
if [[ "${branch}" = "main" ]]; then
    git stash
    git fetch origin
    git checkout -b rc/"${version}"
    git stash pop
fi

# Add changes and commit/push to branch
git add .
git commit -m "Release v${version}"
git push origin ${branch}

gh release create "v${version}" --title "Release ${version}" --notes "${changelog}" --repo github.com/MOmarMiraj/onepassword-sdk-go

