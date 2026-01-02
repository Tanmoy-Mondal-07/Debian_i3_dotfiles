alias ff='fdfind | fzf'
# cd into directory (forward only)
alias fdcd='cd "$(fdfind -t d . ~/ --hidden --exclude .git | fzf)"'

# open file(s) in nvim (forward only)
alias fdef='nvim $(fdfind -t d . ~/ --hidden --exclude .git | fzf)'
alias fde='nvim $(fdfind -t f . --hidden --exclude .git | fzf -m --preview "glow -s tokyo-night {}")'

# config-only navigation
alias fdconf='cd "$(fdfind -t d . ~/.config --hidden --exclude .git | fzf)"'

export GEMINI_API_KEY=geminiapikey
alias ask="~/.config/scripts/gemini.sh"
alias install="sudo apt install"
# cat ~/.cache/wal/sequences
fastfetch