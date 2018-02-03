alias textedit='open -a TextEdit'
if [ -f ~/.git-completion.bash ]; then
    . ~/.git-completion.bash
fi

export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH
export GREP_OPTIONS='--color=auto'
export EDITOR=vim

# use color by default
export CLICOLOR=1

# default: PS1='\h:\W \u\$'
# hostname cwd $
PS1="\[$(tput setaf 2)\]\h \[$(tput setaf 4)\]\W \[$(tput setaf 10)\]$ \[$(tput sgr0)\]"
