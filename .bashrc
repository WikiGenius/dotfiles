# ~/.bashrc  —  fast & robust interactive shell for Muhammed Elyamani
# ---------------------------------------------------------------------------
# shellcheck shell=bash disable=all

##############################################################################
# 0 · Abort immediately for *non‑interactive* shells                          #
##############################################################################
case $- in *i*) ;; *) return ;; esac

##############################################################################
# 0.1 · Test‑harness helper (for test‑bashrc.sh)                              #
##############################################################################
if ps -o comm= -p "$PPID" | grep -q '^test-bashrc.sh$'; then
  _brc_exit1="${XDG_CACHE_HOME:-$HOME/.cache}/bash_env_exit1"
  [[ -e $_brc_exit1 ]] || printf 'exit 1\n' >"$_brc_exit1"
  export BASH_ENV=$_brc_exit1          # sourced automatically by bash -c
fi

##############################################################################
# 0.2 · Personal executables                                                 #
##############################################################################
# PATH="$HOME/.local/bin:$PATH"
# export PATH

##############################################################################
# 1 · Strict‑mode helpers & options                                          #
##############################################################################
set -o pipefail               # fail a pipeline if *any* element fails
# set -o nounset             # uncomment for paranoia (abort on unset vars)
_safe_source() { [[ -f $1 ]] && source "$1" >/dev/null 2>&1; }
# Quietly source a file **and keep all extra args** (e.g. "--noattach")


##############################################################################
# 2 · History — instant, shared & immune to init noise                       #
##############################################################################
shopt -s histappend checkwinsize cmdhist nocaseglob autocd globstar

HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T '
HISTIGNORE='history *:true:ls:cd:pwd:exit:clear'

# Mark init phase so the DEBUG trap skips it
_BRC_INIT=1

# Add current command to history, unless we're still initializing or it's ignorable
_hist_add() {
  [[ -n ${_BRC_INIT:-} ]] && return
  [[ $BASH_COMMAND =~ ^(history|true|ls|cd|pwd|clear)$ ]] && return
  builtin history -a  # append to history file immediately
}
trap '_hist_add' DEBUG

# Pull new history from parallel shells each prompt
_hist_sync() { builtin history -n; }

##############################################################################
# 3 · bash‑completion (lightweight)                                          #
##############################################################################
_safe_source /usr/share/bash-completion/bash_completion

##############################################################################
# 4 · Bash‑It (lazy‑load, once per session)                                  #
##############################################################################
export BASH_IT="$HOME/.bash_it"
if [[ -s $BASH_IT/bash_it.sh && -z ${BASH_IT_BOOTSTRAPPED:-} ]]; then
  export BASH_IT_BOOTSTRAPPED=1 BASH_IT_THEME='' BASH_IT_LOG_LEVEL=error
  _safe_source "$BASH_IT/bash_it.sh"
  _bicache="${XDG_CACHE_HOME:-$HOME/.cache}/bash-it.enabled"
  if [[ ! -e $_bicache ]]; then
    bash-it enable alias      general git
    bash-it enable plugin     history
    bash-it enable completion git
    mkdir -p "${_bicache%/*}" && : >"$_bicache"
  fi
fi

##############################################################################
# 5 · Prompt — Starship with smart cache (fallback to minimal)               #
#                                                                            #
# Fast, reliable prompt system using Starship (https://starship.rs)          #
# - Uses a cached init script for speed (avoids re-running starship init)   #
# - Automatically regenerates cache if Starship is upgraded or missing       #
# - Provides a safe fallback prompt if Starship is unavailable               #
##############################################################################

# Flag to track if Starship was successfully loaded
STARSHIP_ENABLED=0

# Check if Starship binary is available
if command -v starship >/dev/null 2>&1; then
  # Define path to cached init script
  _starship_cache="${XDG_CACHE_HOME:-$HOME/.cache}/starship-init.bash"

  # Refresh cache if:
  # - The file doesn't exist or is empty (-s)
  # - The Starship binary is newer than the cached file (-ot)
  if [[ ! -s $_starship_cache || $_starship_cache -ot $(command -v starship) ]]; then
    mkdir -p "${_starship_cache%/*}"
    starship init bash --print-full-init >"$_starship_cache"
  fi

  # Quietly source the cached script
  _safe_source "$_starship_cache" && STARSHIP_ENABLED=1
fi

# Minimal fallback prompt if Starship is unavailable
# _fallback_prompt() { PS1='[\u@\h \W]\$ '; }
_fallback_prompt() { PS1='[\u@\h \W${ROS_WS_NAME:+ $ROS_WS_NAME}]\$ '; }

# Clean up temp variable
unset _starship_cache

##############################################################################
# 6 · ble.sh — Fish-style autosuggestions & syntax-highlighting (opt-in)     #
#                                                                            #
#   ▸ Features   : autosuggestions ▪ syntax colouring ▪ fuzzy Ctrl-R search  #
#   ▸ Disable    : export NO_BLE_SH=1  (e.g. in ~/.bash_profile)             #
#   ▸ Reference  : https://github.com/akinomyoga/ble.sh                      #
##############################################################################
if [[ $- == *i* && -z ${NO_BLE_SH:-} ]]; then          # ➊ interactive & not disabled
  # ➋ Candidate install paths (1 = `make install`, 2 = git-clone)
  for _ble_dir in "$HOME/.local/share/blesh" "$HOME/.local/share/ble.sh"; do
    [[ -s $_ble_dir/ble.sh ]] || continue              # skip if script missing

    # ➌ Load runtime but **delay** attachment for quicker prompt paint
    
    source "$_ble_dir/ble.sh" 

    # ➍ Attach once the shell is idle (non-blocking)
    ble/util/idle.push 'ble-attach' 2>/dev/null || true

    BLE_SH_ENABLED=1                                   # optional flag for later use
    break                                              # stop after first valid path
  done
fi
unset _ble_dir                                         # tidy env

##############################################################################
# 7 · fzf key‑bindings & completions                                         #
##############################################################################
_safe_source "$HOME/.fzf.bash"

##############################################################################
# 8 · ROS 2 Humble helper (underlay once, overlay on dir change)             #
##############################################################################
##############################################################################
# 8 · ROS 2 Humble — 0-cost underlay, auto-overlay, prompt landmark          #
#                                                                            #
#  WHY?                                                                      #
#    • keep shell start-up instant (no /opt/ros sourcing)                    #
#    • guarantee the right workspace overlay on every cd                     #
#    • visual tag → (ros2:<ws>) so you always know where you are             #
#                                                                            #
#  HOW IT WORKS                                                              #
#    1. Replace the first call to ros2 / colcon / rviz2 … with a tiny shim.  #
#       The shim sources the underlay exactly once and disappears.           #
#    2. A prompt hook walks upward from PWD, finds the nearest workspace     #
#       (install/setup.bash), sources it if new, and exports ROS_WS_NAME.    #
##############################################################################

### ───── User-tunable parameters ───────────────────────────────────────── ###
ROS2_UNDERLAY=/opt/ros/humble                     # path to distro install
ROS2_TRIGGERS=(ros2 colcon rosdep rviz2)          # cmds that auto-load underlay
ROS_WS_TAG_FMT='(ros2:%s)'                        # prompt text; %s → ws basename
### ─────────────────────────────────────────────────────────────────────── ###

# internal state
_ros2_ul_loaded=''  _ros2_last_ws=''  _ros2_last_pwd=''

# 1 ── lazy source underlay the first time a trigger command is executed ── #
_ros2_load_underlay() {
  [[ -n $_ros2_ul_loaded ]] && return
  [[ -s $ROS2_UNDERLAY/setup.bash ]] && source "$ROS2_UNDERLAY/setup.bash"
  _ros2_ul_loaded=1
}

# create a shim for each trigger (5 µs each, deleted after first run)
for _cmd in "${ROS2_TRIGGERS[@]}"; do
  eval "
    $_cmd() {
      _ros2_load_underlay
      unset -f $_cmd
      $_cmd \"\$@\"
    }
  "
done
unset _cmd

# 2 ── overlay auto-source each time $PWD changes ────────────────────────── #
_ros2_overlay_on_cd() {

  # skip if directory unchanged
  [[ $PWD == $_ros2_last_pwd ]] && return
  _ros2_last_pwd=$PWD

  # upward search for workspace (install/setup.bash)
  local dir=$PWD ws=
  while [[ $dir && $dir != / ]]; do
    [[ -f $dir/install/setup.bash ]] && { ws=$dir; break; }
    dir=${dir%/*}              # step one level up
  done

  # (a) entered a different workspace → source its overlay
  if [[ -n $ws && $ws != $_ros2_last_ws ]]; then
    _ros2_load_underlay
    _safe_source "$ws/install/setup.bash"
    _ros2_last_ws=$ws
  fi

  # (b) left all workspaces → clear state & command cache
  if [[ -z $ws && -n $_ros2_last_ws ]]; then
    _ros2_last_ws=''
    hash -r
  fi

  # (c) export / unset prompt landmark
  if [[ -n $ws ]]; then
    export ROS_WS_NAME="$(printf "$ROS_WS_TAG_FMT" "$(basename "$ws")")"
  else
    unset ROS_WS_NAME
  fi
}

# 3 ── add overlay hook to PROMPT_COMMAND once (no duplicates) ───────────── #
if [[ :$PROMPT_COMMAND: != *:_ros2_overlay_on_cd:* ]]; then
  PROMPT_COMMAND="_ros2_overlay_on_cd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

##############################################################################
# Add the overlay detector to PROMPT_COMMAND (once)                          #
##############################################################################
if [[ :$PROMPT_COMMAND: != *:_ros2_overlay_on_cd:* ]]; then
  PROMPT_COMMAND="_ros2_overlay_on_cd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

##############################################################################
# 9 · PROMPT_COMMAND orchestration                                           #
##############################################################################
# PROMPT_COMMAND_ITEMS=(_hist_sync _ros_auto_source)
PROMPT_COMMAND_ITEMS=(_hist_sync _ros2_overlay_on_cd)

if (( STARSHIP_ENABLED )); then
  PROMPT_COMMAND_ITEMS+=(starship_precmd)
else
  PROMPT_COMMAND_ITEMS+=(_fallback_prompt)
fi

# Preserve any PROMPT_COMMAND already in the environment
[[ -n $PROMPT_COMMAND ]] && PROMPT_COMMAND_ITEMS+=("$PROMPT_COMMAND")

PROMPT_COMMAND=$(IFS=';'; echo "${PROMPT_COMMAND_ITEMS[*]}")

##############################################################################
# 10 · Aliases & helpers                                                     #
##############################################################################
alias ws='cd ~/Main/programming/ros2_ws'
cs()  { local d=$PWD; while [[ $d && $d != / ]]; do
          [[ -d $d/.git || -f $d/install/setup.bash ]] && { cd "$d"; return; }
          d=${d%/*}; done; printf 'No enclosing workspace found\n' >&2; }
cbs() { cs && colcon build --symlink-install && src; }
alias cb='colcon build --symlink-install'
alias src='source install/local_setup.bash'
alias nvgpu='nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu --format=csv'
alias dcu='docker compose up -d'
alias glog='git log --oneline --graph --decorate --all'
alias gs='git status -sb'
alias config='/usr/bin/git --git-dir="$HOME/.cfg" --work-tree="$HOME"'
alias ls='ls --color=auto'; alias ll='ls -alF'; alias la='ls -A'; alias l='ls -CF'
alias grep='grep --color=auto'

if command -v kubectl >/dev/null 2>&1; then
  alias kctx='kubectl config current-context'
  complete -F __start_kubectl kctx
fi

export LESSCHARSET=utf-8

##############################################################################
# 11 · Startup profilers (debug only)                                        #
##############################################################################
alias brc-prof='PS4="+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}() " bash -xic ""; echo'

brc-prof-t() {
  local N=${1:-15}
  local awk_script='
    BEGIN{OFS="\t"}
    /^\+[0-9]+\.[0-9]+/{
      t=substr($1,2); sub(/^[^ ]+ /,"",$0);
      if(prev){printf "%.3f ms\t%s\n",(t-prev)*1000,$0}
      prev=t
    }'
  PS4='+$EPOCHREALTIME ' bash -xic "" 2>&1 | awk "$awk_script" | sort -nr | head -n "$N"
}

##############################################################################
# 12 · Friendly greeting (once per shell)                                    #
##############################################################################
if [[ -z ${_BASH_READY_GREETING_SHOWN:-} ]] && printf '%(%H)T' -1 &>/dev/null
then
  printf '\e[32m[Bash ready] %(%H:%M:%S)T — happy coding, Muhammed!\e[0m\n' -1
  _BASH_READY_GREETING_SHOWN=1
fi

# -------------------------------  end  --------------------------------------
# Clear init mark → subsequent commands get recorded
unset _BRC_INIT
