#!/bin/bash

# Check if the first argument ($1) is empty
if [ -z "$1" ]; then
    echo "Repository name is empty. Using existing repository name from my_repo.sh..."
    if [ -f my_repo.sh ]; then
        . my_repo.sh
    else
        echo "Error: my_repo.sh not found. Please provide a repository name or ensure my_repo.sh exists."
        usage
        exit 1
    fi
else
    # Create or update my_repo.sh with the provided repository name
    REPOSITORY="$1"
    printf '#!/bin/bash\nexport REPOSITORY=%s\n' "$REPOSITORY" > my_repo.sh
    chmod +x ~/workspace/scripts/github/my_repo.sh
    . my_repo.sh
fi

# Verify that REPOSITORY is set
if [ -z "$REPOSITORY" ]; then
    echo "Error: REPOSITORY is not set. Please check my_repo.sh or provide a valid repository name."
    usage
    exit 1
fi


cd ../

# Source the GitHub configuration file
if [ -f ~/workspace/scripts/github/my_github.sh ]; then
    . ~/workspace/scripts/github/my_github.sh
else
    echo "Error: my_github.sh not found. Please ensure it exists and contains GITHUB_USERNAME and GITHUB_TOKEN."
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: $0 <repository name>"
    echo "Example: $0 my_repo"
}

# Check if required environment variables are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_USERNAME or GITHUB_TOKEN is not set in my_github.sh."
    exit 1
fi

# Display repository details
echo "Creating repository: $REPOSITORY"
echo "Username: $GITHUB_USERNAME"
echo "Token: **********"  # Mask the token for security

cd ~/workspace/scripts/github/

# Execute the create_repo.sh script
if [ -f ./create_repo.sh ]; then
    ./create_repo.sh -u "$GITHUB_USERNAME" -p "$GITHUB_TOKEN" -r "$REPOSITORY"
    if [ $? -eq 0 ]; then
        echo "Repository '$REPOSITORY' created successfully."
    else
        echo "Failed to create repository '$REPOSITORY'."
        exit 1
    fi
else
    echo "Error: create_repo.sh not found. Please ensure it exists and is executable."
    exit 1
fi


