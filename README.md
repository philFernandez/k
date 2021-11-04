# `k` is like `z` or `j`

This only works in `zsh`, requires `fzf`, and gnu `awk`. Tested on macOS with `gawk` (gnu awk) installed via homebrew. Also requires `bat`
for preview window functionality.

This is meant to be an autoloaded zsh function. To make it work --

1) Put in in a directory that is in `fpath`
1) `autoload k` in startup files
1) Reload your shell and press `k`
1) Follow simple on-screen instructions

`k` was chosen because it is on the keyboard's home row and easy to get to quickly.

### Dependencies
* [gawk](https://formulae.brew.sh/formula/gawk)
* [fzf](https://github.com/junegunn/fzf)
* [bat](https://github.com/sharkdp/bat)

### How to Autoload Functions (and other things to make ZSH faster)
* [htr3n.github.io/2018/07/faster-zsh/](https://htr3n.github.io/2018/07/faster-zsh/)
