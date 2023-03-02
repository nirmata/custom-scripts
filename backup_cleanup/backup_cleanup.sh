#!/bin/bash

# Prompt the user for the directory path
read -p "Enter the directory path: " dir_path

# Check if the directory exists
if [ ! -d "$dir_path" ]; then
  echo "Error: Directory not found."
  exit 1
fi

# Confirm with the user before proceeding
read -p "Are you sure you want to delete files older than 30 days in $dir_path? (y/n) " confirm
if [ "$confirm" != "y" ]; then
  echo "Aborted."
  exit 0
fi

# Remove all files in the directory that are older than 30 days
echo "Removing files older than 30 days in $dir_path..."
find "$dir_path" -type f -mtime +30 -exec sh -c 'echo "Removing {}"; rm {}' \;
echo "Done."
