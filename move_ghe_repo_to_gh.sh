# this moves content from GHE to GH (IBM)
# the first arg is the org name
# the second arg is the repo name, which will be used for the new repo as well

echo "remember to create the repo at https://github.com/ibm before running this"

org=$1
repo=$2

## clone the repo to be moved and cd into it
git clone git@github.ibm.com:$1/$2.git
cd $2

## rename the origin branch to something else to avoid conflicts
git remote rename origin deleteme

## go to github and create an empty repo, add the new repo location
git remote add origin https://github.com/IBM/$2.git

## remove the old one
git remote remove deleteme

## push code up to new remote branch
git push -u origin master

## note that if using the below command with 2FA, you will need to
## use a personal access token as a password along with your username!
