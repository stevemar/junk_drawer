# the first arg is the new repo name

repo=$1

cd journey-template
git pull origin master
cd ..

git clone git@github.ibm.com:developer-journeys/$1.git
cd $1

cp -R ../journey-template/* .
git add *
git commit -m "init repo"
git push
