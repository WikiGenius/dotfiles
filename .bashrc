# ~/.bashrc — Fast, clean interactive shell for Muhammed Elyamani
# ────────────────────────────────────────────────────────────────────────────
# ❶ Bail out early for non-interactive shells
[[ $- != *i* ]] && return

##############################################################################
# 0 · Strict-mode helpers                                                    #
##############################################################################
set -o pipefail                      # fail pipeline if *any* element fails
# set -o nounset                     # uncomment for paranoia: error on unset

# Source a file only if it exists; silence its chatter
_safe_source() { [[ -f "$1" ]] && source "$1" >/dev/null 2>&1 ; }

##############################################################################
# 1 · History & shell behaviour                                              #
##############################################################################
shopt -s histappend checkwinsize cmdhist nocaseglob autocd globstar
HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T '            # show timestamps in reverse-i-search

##############################################################################
# 2 · bash-completion (lightweight)                                          #
##############################################################################
_safe_source /usr/share/bash-completion/bash_completion

##############################################################################
# 3 · Bash-it (loaded **once** per session)                                  #
##############################################################################
export BASH_IT="$HOME/.bash_it"
if [[ -s $BASH_IT/bash_it.sh && -z ${BASH_IT_BOOTSTRAPPED:-} ]]; then
  export BASH_IT_BOOTSTRAPPED=1
  export BASH_IT_THEME=''                       # Starship handles prompt
  export BASH_IT_LOG_LEVEL=error                # hush verbose logging
  _safe_source "$BASH_IT/bash_it.sh"

  # Curated minimal enable set (runs only first time → cached)
  _bash_it_cache="${XDG_CACHE_HOME:-$HOME/.cache}/bash-it.enabled"
  mkdir -p "${_bash_it_cache%/*}"
  if [[ ! -e "$_bash_it_cache" ]]; then
    bash-it enable alias      general git
    bash-it enable plugin     history
    bash-it enable completion git
    touch "$_bash_it_cache"
  fi
fi

##############################################################################
# 4 · Prompt — Starship (fast cache)                                         #
##############################################################################
STARSHIP_ENABLED=0
if command -v starship >/dev/null 2>&1; then
  _starship_cache="${XDG_CACHE_HOME:-$HOME/.cache}/starship-init.bash"
  # Re-generate cache after Starship upgrades
  if [[ ! -s "$_starship_cache" || "$_starship_cache" -ot "$(command -v starship)" ]]; then
    mkdir -p "${_starship_cache%/*}"
    starship init bash --print-full-init >"$_starship_cache"
  fi
  _safe_source "$_starship_cache"
  STARSHIP_ENABLED=1
fi

# Fallback prompt (executes each time in case Starship misbehaves)
_fallback_prompt() { [[ -z $PS1 ]] && PS1='\u@\h:\w\$ '; }

##############################################################################
# 5 · ble.sh autosuggestions (optional)                                      #
##############################################################################
if [[ -z ${NO_BLE_SH:-} ]]; then
  BLE_HOME="$HOME/.local/share/ble.sh"
  if [[ -s $BLE_HOME/ble.sh ]]; then
    _safe_source "$BLE_HOME/ble.sh" --noattach        # lazy attach
    ble/util/idle.push 'ble-attach' 2>/dev/null || true
  fi
fi

##############################################################################
# 6 · fzf key-bindings & completions                                         #
##############################################################################
_safe_source "$HOME/.fzf.bash"

##############################################################################
# 7 · ROS 2 Humble helper (underlay-once, overlay-on-cd, zero-latency)       #
##############################################################################
_ros_underlay_done=       # flag → have we already sourced the underlay?
_ros_last_pwd=''          # last directory examined
_ros_last_ws=''           # last overlay workspace sourced

_ros_auto_source() {

  # 1️⃣ Source /opt/ros/humble exactly once per interactive shell
  if [[ -z $_ros_underlay_done ]]; then
    _safe_source /opt/ros/humble/setup.bash
    _ros_underlay_done=1
  fi

  # 2️⃣ Skip everything if we haven’t moved since last prompt
  [[ $PWD == $_ros_last_pwd ]] && return
  _ros_last_pwd=$PWD

  # 3️⃣ Walk up to the nearest install/setup.bash (overlay)
  local dir=$PWD ws=
  while :; do
    [[ -f "$dir/install/setup.bash" ]] && { ws=$dir; break; }
    [[ $dir == / ]] && break                    # reached filesystem root
    dir=${dir%/*} ; [[ -z $dir ]] && dir=/
  done

  # 4️⃣ (Re)source overlay only if it changed
  if [[ -n $ws && $ws != "$_ros_last_ws" ]]; then
    _safe_source "$ws/install/setup.bash"
    _ros_last_ws=$ws
  fi

  # 5️⃣ Left all overlays? —› de-source to avoid stale env
  if [[ -z $ws && -n $_ros_last_ws ]]; then
    _ros_last_ws=''
    hash -r        # clear command hash table
  fi
}

##############################################################################
# 8 · PROMPT_COMMAND orchestration                                           #
##############################################################################
PROMPT_COMMAND_ITEMS=(_ros_auto_source)          # always run ROS helper

if (( STARSHIP_ENABLED )); then
  PROMPT_COMMAND_ITEMS+=(starship_precmd)
else
  PROMPT_COMMAND_ITEMS+=(_fallback_prompt)
fi

PROMPT_COMMAND_ITEMS+=(_fallback_prompt)         # guarantee a prompt
PROMPT_COMMAND=$(IFS=';'; echo "${PROMPT_COMMAND_ITEMS[*]}")

##############################################################################
# 9 · Aliases & helpers                                                      #
##############################################################################
# ⏩ Fast jump to main ROS 2 workspace
alias ws='cd /home/elyamani/Main/programming/ros2_ws'

# Optional smart wrapper: uncomment to allow `ws src/…`
# ws () { local base=/home/elyamani/Main/programming/ros2_ws; cd "$base/${1:-}"; }

# Quick jump to topmost ROS or Git workspace containing src/
cs() {
  local dir="$PWD"
  while [[ $dir && $dir != / ]]; do
    [[ -d $dir/.git || -f $dir/install/setup.bash ]] && { cd "$dir"; return; }
    dir=${dir%/*}
  done
  echo "No enclosing workspace found" >&2
}
cbs() { cs && colcon build --symlink-install && src; }  # build & re-source

# Common dev shortcuts
alias cb='colcon build --symlink-install'
alias src='source install/local_setup.bash'
alias nvgpu='nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu --format=csv'
alias dcu='docker compose up -d'
alias glog='git log --oneline --graph --decorate --all'
alias gs='git status -sb'
alias config='/usr/bin/git --git-dir=/home/elyamani/.cfg --work-tree=/home/elyamani'

# Colourised coreutils & grep
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# kubectl helpers (if present)
if command -v kubectl >/dev/null; then
  alias kctx='kubectl config current-context'
  complete -F __start_kubectl kctx
fi

# UTF-8 pager
export LESSCHARSET=utf-8

##############################################################################
# 10 · Gitstatus threading (Starship reads this)                             #
##############################################################################
# export GITSTATUS_NUM_THREADS=4   # tune if large repos burn CPU

##############################################################################
# 11 · Startup profilers (debug only)                                        #
##############################################################################
alias brc-prof='PS4="+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}() " bash -xic ""; echo'
brc-prof-t() {
  local awk_script='BEGIN{OFS="\t"} /^\+[0-9]+\.[0-9]+/{now=substr($1,2);sub(/^[^ ]+ /,"");if(prev){printf "%.3f ms\t%s\n",(now-prev)*1000,$0};prev=now}'
  PS4='+$EPOCHREALTIME ' bash -xic "" 2>&1 | awk "$awk_script"
}

##############################################################################
# 12 · Friendly greeting (runs once per interactive shell)                   #
##############################################################################
if [[ -z ${_BASH_READY_GREETING_SHOWN:-} ]] && printf '%(%H)T' -1 &>/dev/null
then
  printf '\e[32m[Bash ready] %(%H:%M:%S)T — happy coding, Muhammed!\e[0m\n' -1
  _BASH_READY_GREETING_SHOWN=1
fi
