# Run these commands to set up the VM:

# sudo add-apt-repository ppa:webupd8team/java
# sudo apt-get update
# sudo apt-get install -y python-pip
# sudo apt-get install -y oracle-java8-set-default
# export GH_TOKEN=...
# pip install flake8 html5validator j2cli[yaml] yamllint pyyaml
# git config --global user.email "cron@ibm.com"
# git config --global user.name "Cron VM"
# Run crontab -e to setup cron job
# 10 * * * * /root/cartographer.sh

# Clone the repo and setup upstream so we can push HEAD:master
git clone https://${GH_TOKEN}@github.ibm.com/stevemar/cartographer.git cartographer
cd cartographer
git remote add upstream https://${GH_TOKEN}@github.ibm.com/stevemar/cartographer.git

# Pull new data
git clone --depth 1 https://${GH_TOKEN}@github.ibm.com/IBMCode/Code-Patterns.git Code-Patterns
python generate_data.py --path="Code-Patterns"
git clone --depth 1 https://${GH_TOKEN}@github.ibm.com/IBMCode/Code-Tutorials.git Code-Tutorials
python generate_data.py --path="Code-Tutorials"
git clone --depth 1 https://${GH_TOKEN}@github.ibm.com/IBMCode/Code-Blogs.git Code-Blogs
python generate_data.py --path="Code-Blogs"
git clone --depth 1 https://${GH_TOKEN}@github.ibm.com/IBMCode/Code-Videos.git Code-Videos
python generate_data.py --path="Code-Videos"
git clone --depth 1 https://${GH_TOKEN}@github.ibm.com/IBMCode/Code-Articles.git Code-Articles
python generate_data.py --path="Code-Articles"

# Only do these steps if something has changed, ignore untracked files
if [ -z "$(git status --porcelain -uno)" ]; then
    # Working directory clean
    echo "Nothing to commit"
    exit 0
else
    # Uncommitted changes
    git add *.yaml
    rm -rf Code-*
    # Regenerate HTML
    ./render.sh
    git add *.html
    git commit --message "Update data via cron job"
    git push upstream HEAD:master
fi
