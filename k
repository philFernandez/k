# TODO: use chpwd_functions to automatically collect visited directories

local -A args_and_flags
zparseopts -D -A args_and_flags -- a:: h f

# k_cache holds location of cache file
local k_cache query is_query show_full_path
local RED="$(tput setaf 1)"
local GREEN="$(tput setaf 2)"
local YELLOW="$(tput setaf 3)"
local BOLD="$(tput bold)"
local RS="$(tput sgr0)"

# Help Message
[[ ${(k)args_and_flags} = '-h' ]] && {
  cat << EOF
${YELLOW}USAGE:${RS}
     k [-a [<dir>]] | [-f] [<query>] | [-h]

${YELLOW}FLAGS:${RS}
    ${GREEN}-a <dir>${RS} Add dir to cache, or add PWD if dir is ommited.
    ${GREEN}-f${RS}       Show and search full path.
             Default is to show parent/dir and search by dir.
    ${GREEN}-h${RS}       Show this help message.

${YELLOW}ARGS:${RS}
    ${GREEN}<query>${RS}  Start fuzzy finder with query as search term.
             If query only returns one match, cd to match without opening
             fuzzy finder.

${YELLOW}KEY BINDINGS:${RS}
    ${GREEN}ctrl-u${RS}   Deletes current line in fuzzy finder from cache.
    ${GREEN}ctrl-l${RS}   Toggles ls preview window.

${YELLOW}ENVIRONMENT:${RS}
    ${GREEN}K_TOGGLE_PREV${RS}   Set keyboard shortcut for ls preview toggle.
                    Accepts any keyboard shortcut that is valid
                    in FZF.
    ${GREEN}K_REMOVE_ENTRY${RS}  Set keyboard shortcut for removal of directory
                    from cache.

EOF
  return 0
}

# Set show_full_path flag for instructing fzf to show full path
[[ ${(k)args_and_flags} = '-f' ]] && {
  show_full_path=1
}

# If ~/.cache exists, put the k_cache file there.
# Else put it in ~/
if [[ -d $HOME/.cache ]]; then
  k_cache=$HOME/.cache/k_cache
else
  k_cache=$HOME/.k_cache
fi

# Parse any argument that may have come in in addition to the flags
case $1 in
  -*) # If positional parameter is not caught by zparseopts, then its an error
    print -u2 "${RED}${BOLD}error${RS}: ${YELLOW}\"$1\"${RS} is an invalid option."
    return 1
    ;;
  *) # If single non-option parameter is passed in, treat it as a query for fzf
    query=$@
    is_query=1
esac

# Handle -a flag and its argument
if [[ ${(k)args_and_flags} = '-a' ]]; then
  # If -a was not given an argument, assign it to PWD
  [[ ! $args_and_flags[-a] ]] && {
    args_and_flags[-a]=$PWD
  }
  if [[ -d $args_and_flags[-a] ]]; then
    local newdir
    newdir=${args_and_flags[-a]:gs/~\//$HOME/}
    if [[ $newdir[1] != '/' ]]; then
      newdir="${PWD}/${newdir}"
    fi
    # Remove any trailing '/' because fzf uses '/' as
    # a field delimiter, and having one on the end will
    # cause problems
    if [[ $newdir[-1] == '/' ]]; then
      newdir=$newdir[1,-2]
    fi
    echo ${(q-)newdir} >>! $k_cache
    sort -uC <(sort $k_cache)
    if [[ $? != 0 ]]; then
      print -u2 "$newdir already exists"
      gawk -i inplace '!seen[$0]++' $k_cache
      return 1
    fi
  else
    print -u2 "$args_and_flags[-a] is not a valid directory."
    return 1
  fi
  return 0
fi

# First run / empty cache message
if [[ ! -s $k_cache ]]; then
  cat << EOF
${BOLD}${YELLOW}Setup:${RS}
"k" needs at least one directory in the cache
in order to work.

Use the option ${GREEN}-a${RS} to add some directories.

${BOLD}${YELLOW}For Example:${RS}
${GREEN}k -a${BOLD} ~/${RS} will add your home directory.

Go around your file system and add some directories that
you use frequently. You can either put in absolute paths
or put in paths that are relative to your present working
directory.

When there are only one, or two directories stored in the
cache, this utility will just swith to that one directory
if there is one, or switch between the two if there are
two. If you have three or more directories in the cache
the fuzzy finder will open.

Once you add at least one directory you will no longer
see this help message, unless you delete the cache
file residing either at ~/.k_cache, or ~/.cache/k_cache
EOF
return 1
fi

# Remove directories from cache which are no longer on disk
local directories=( "${(@f)$(<$k_cache)}" )
local -a removed_dirs
for dir in $directories; do
  if [[ ! -d ${(Q)dir} ]]; then
    removed_dirs+=($dir)
    command sed -i.old "\:^$dir$:d" $k_cache && \
      command rm -f "$k_cache.old"
  fi
done
unset dir
[[ $removed_dirs ]] && {
  print -- ${YELLOW}Directories cleared from cache...${RS}
  print -l -- $removed_dirs
}

# Handle case of cache containing only 1 or 2 entries
local cache_len=$(awk 'END{print NR}' $k_cache)
if [[ $cache_len == 1 ]]; then
  local single_dir=( $(<$k_cache) )
  if [[ $single_dir == $PWD ]]; then
    echo "$PWD is the only directory in cache."
  else
    # use eval to handle directories with spaces
    eval "cd $single_dir"
    echo "$single_dir is the only directory in cache."
  fi
  return 0
fi

# FZF Options -------------------------------------------------------
local preview
if [[ ${+commands[lsd]} -eq 1 ]]; then
  preview="eval lsd -A --color=always --icon=always --group-dirs first {}"
else
  case $(uname) in
    "Darwin")
      preview="eval ls -F -A -G {}"
      ;;
    "Linux")
      preview="eval ls -A --color=auto --group-directories-first"
      ;;
  esac
fi

if [[ ! $K_TOGGLE_PREV ]]; then
  K_TOGGLE_PREV="ctrl-l"
fi
if [[ ! $K_REMOVE_ENTRY  ]]; then
  K_REMOVE_ENTRY="ctrl-u"
fi
local filter_pwd="grep -Ev \"("^\'$PWD\'$"|"^$PWD$")\" $k_cache"
local remove_entry="${K_REMOVE_ENTRY}:execute-silent( \
command sed -i.old '\:^'{}'$:d' $k_cache && \
command rm -f $k_cache.old)+reload($filter_pwd)"
local directory
local toggle_preview="${K_TOGGLE_PREV}:toggle-preview"

[[ ! $K_HEADER_BGCOLOR ]] && {
  K_HEADER_BGCOLOR=035
}
[[ ! $K_HEADER_FGCOLOR ]] && {
  K_HEADER_FGCOLOR=016
}
[[ ! $K_HEIGHT ]] && {
  K_HEIGHT=30%
}
[[ ! $K_PREVIEW_SIZE ]] && {
  K_PREVIEW_SIZE=40%
}
[[ ! $K_LINE_MATCH_COLOR ]] && {
  K_LINE_MATCH_COLOR=120
}
[[ ! $K_SUBSTR_MATCH_COLOR ]] && {
  K_SUBSTR_MATCH_COLOR=$K_LINE_MATCH_COLOR
}
[[ ! $K_GUTTER_COLOR ]] && {
  K_GUTTER_COLOR=240
}
[[ ! $K_POINTER_COLOR ]] && {
  K_POINTER_COLOR=220
}
[[ ! $K_FOREGROUND ]] && {
  K_FOREGROUND=15
}
[[ ! $K_LINE_BG_COLOR ]] && {
  K_LINE_BG_COLOR=$K_GUTTER_COLOR
}
[[ ! $K_LINE_FG_COLOR ]] && {
  K_LINE_FG_COLOR=3
}
[[ ! $K_BORDER_COLOR ]] && {
  K_BORDER_COLOR=$K_GUTTER_COLOR
}
[[ ! $K_PROMPT_COLOR ]] && {
  K_PROMPT_COLOR=214
}
# Next do prompt color

local header="$(print -P '%F{$K_HEADER_BGCOLOR}\ue0b6%f%K{$K_HEADER_BGCOLOR}%F{$K_HEADER_FGCOLOR}%Bpwd  %~%k%b%F{$K_HEADER_BGCOLOR}\ue0b4%f')"
# -------------------------------------------------------------------

# FZF Execution -----------------------------------------------------

[[ $show_full_path ]] && { # This is where we go with -f
  directory=$(grep -Ev "("^\'$PWD\'$"|"^$PWD$")" $k_cache | fzf \
  --height $K_HEIGHT -1 --no-info --header=$header --bind $remove_entry \
  --layout=reverse-list --cycle --preview $preview \
  --preview-window=right:$K_PREVIEW_SIZE --bind $toggle_preview \
  --color hl:$K_SUBSTR_MATCH_COLOR --color hl+:$K_LINE_MATCH_COLOR \
  --color gutter:$K_GUTTER_COLOR --color pointer:$K_POINTER_COLOR \
  --color fg:$K_FOREGROUND --color border:$K_BORDER_COLOR --border \
  --color bg+:$K_LINE_BG_COLOR --color fg+:$K_LINE_FG_COLOR \
  --color prompt:$K_PROMPT_COLOR -q "$query")

true } || { # This is where we go without -f
  directory=$(grep -Ev "("^\'$PWD\'$"|"^$PWD$")" $k_cache | fzf --height $K_HEIGHT \
  -1 --no-info -n -1 -d '/' --header=$header --bind \
  $remove_entry --with-nth=-2,-1 --layout=reverse-list --cycle --preview \
  $preview --preview-window=right:$K_PREVIEW_SIZE --bind $toggle_preview \
  --color hl:$K_SUBSTR_MATCH_COLOR --color hl+:$K_LINE_MATCH_COLOR \
  --color gutter:$K_GUTTER_COLOR --color pointer:$K_POINTER_COLOR \
  --color fg:$K_FOREGROUND --color border:$K_BORDER_COLOR --border \
  --color bg+:$K_LINE_BG_COLOR --color fg+:$K_LINE_FG_COLOR \
  --color prompt:$K_PROMPT_COLOR -q "$query")
}
# -------------------------------------------------------------------

if [[ -n $directory ]]; then
  # use eval so directories with space in them dont fail
  eval "cd $directory"
  return 0
fi

# vi: ft=zsh cc=80
