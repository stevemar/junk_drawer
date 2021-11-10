#!/bin/bash

# given a path, clean up all git projects in the directory.
# clean meaning...
#   1. checkout master
#   2. delete all non-master branches
#   3. pull down latest code

# save current directory so we can go back after it's run
previous_dir=$(pwd)

# accept a path argument, default to current dir if not supplied
path=$1
if [[ -z "$path" ]]; then
    echo "no path specified, using current directory"
    path=$(pwd)
fi

# TODO: check if path ($1) actually exists, fail if not

# output the folders we will clean
cd $path
folders=$(ls)
echo "cleaning folders:"
echo "================="
echo $folders
echo "================="

# for each folder, do a few checks...
for dir in */; do
    cd $dir
    echo "cleaning folder $dir"

    # check if .git exists, it could just be a folder
    if [ -e ".git" ]; then
        git checkout -f master
        git fetch
        git pull origin master
    else
        echo "skipping $dir as it's not a git project"
    fi
    cd ..
done

# go back home
cd $previous_dir
