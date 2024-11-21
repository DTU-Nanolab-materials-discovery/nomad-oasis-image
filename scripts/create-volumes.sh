#!/bin/bash

# Define the directory structure
dirs=(
  ".volumes"
  ".volumes/fs/north/users"
  ".volumes/fs/public"
  ".volumes/fs/staging"
  ".volumes/fs/tmp"
  ".volumes/mongo"
)

# Create the directories
for dir in "${dirs[@]}"; do
  mkdir -p "$dir"
done

echo ".volumes structure created successfully."