#!/bin/bash

. my_repo.sh

cd ../
. ~/workspace/scripts/github/my_github.sh

echo "git init..."
git init

echo "git add..."
git add .

echo "git commit..."
git commit -m "Initial commit"

echo "Connect github account $GITHUB_USERNAME:$GITHUB_TOKEN"
git remote add origin https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$REPOSITORY.git

git branch -M main

git push -u origin main


