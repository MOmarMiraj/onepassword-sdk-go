#!/bin/bash

# Helper script to prepare a release for the Go SDK.

# Read current build and version for backup as well as comparison to new build
current_build=$(< internal/release/version-build)
current_version=$(< internal/release/version)

version_file="internal/release/version"
build_file="internal/release/version-build"

# Function to execute upon exit
cleanup() {
    echo "Performing cleanup tasks..."
    # Remove changelog file if it exists
    rm -f "${changelog_file}"
    # Revert changes to file if any
    echo "${current_version}" > "${version_file}"
    echo "${current_build}" > "${build_file}"   
}

# Set the trap to call the cleanup function on exit
trap cleanup 1

enforce_latest_code() {
    if [[ -n "$(git status --porcelain=v1)" ]]; then
        echo "ERROR: working directory is not clean."
        echo "Please stash your changes and try again."
        exit 1
    fi
}

# Function to validate the version number format x.y.z(-beta.w)
update_and_validate_version() {
    while true; do
        # Prompt the user to input the version number
        read -p "Enter the version number (format: x.y.z(-beta.w)): " version

        # Validate the version number format
        if [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]]; then        
            # Write the valid version number to the file
            echo "${version}" > "${version_file}"
            echo "New version number is: ${version}"
            return 0
        else
            echo "Invalid version number format: ${version}"
            echo "Please enter a version number in the 'x.y.z(-beta.w)' format."
        fi
    done
}

# Function to validate the build number format.
# SEMVER Format: Mmmppbb - 7 Digits 
update_and_validate_build() {
    while true; do
        # Prompt the user to input the build number
        read -p "Enter the build number (format: Mmmppbb): " build

        # Validate the build number format
        if [[ "${build}" =~ ^[0-9]{7}$ ]]; then
            if (( 10#$current_build < 10#$build )); then
                # Write the valid build number to the file
                echo "${build}" > "${build_file}"
                echo "New build number is: ${build}"
                return 0
            else
                echo "Build version hasn't changed or is less than current build version. Stopping." >&2
                exit 1
            fi
        else
            echo "Invalid build number format: ${build}"
            echo "Please enter a build number in the 'Mmmppbb' format."
        fi
    done
}

# Ensure that the current working directory is clean
enforce_latest_code

# Update and validate the version number
update_and_validate_version

# Update and validate the build number
update_and_validate_build 

changelog_file="internal/release/changelogs/"${version}"-"${build}""

printf "Press ENTER to edit the CHANGELOG in your default editor...\n"
read -r _ignore
${EDITOR:-nano} "$changelog_file"

# Get Current Branch Name
branch="$(git rev-parse --abbrev-ref HEAD)"

# if on main, then stash changes and create RC branch
if [[ "${branch}" = "main" ]]; then
    branch=rc/"${version}"
    git stash
    git fetch origin
    git checkout -b "${branch}"
    git stash apply
fi

# Add changes and commit/push to branch
git add .
git commit -S -m "Release v${version}"
git push --set-upstream origin "${branch}"

echo "Release has been prepared..
Make sure to double check version/build numbers in their appropriate files and
changelog is correctly filled out.
Once confirmed, run 'make release' to release the SDK!"
