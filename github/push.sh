#!/bin/bash

cd ../

. ~/workspace/scripts/github/my_github.sh

echo "git init..."
git init

echo "git add..."
git add .

echo "git commit..."
git commit -m "$(date +"%d.%m.%Y_%H:%M:%S")"

echo "git origin..."
git push -u origin main


