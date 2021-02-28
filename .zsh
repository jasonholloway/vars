# to be sourced by .zshrc

alias v="vars"
alias vr="vars run"
alias vg="vars get"
alias vp="vars pin"
alias vu="vars pin rm"
alias vpc="vars pin clear"
alias vcc="vars cache clear"
alias vpl="vars pin list"
alias vxl="vars context list"
alias vxz="vars context prev"
alias vz="vars context prev"


vars_choose() {
  target=$(vars list | fzy -q ""$1"" -l 20)

  IFS=, read type name <<< "$target"

  case $type in
    T)
      BUFFER="vg $name"
      CURSOR=${#BUFFER}
      ;;
    B)
      BUFFER="vr $name"
      CURSOR=${#BUFFER}
      ;;
  esac

  zle reset-prompt
}

zle -N vars_choose
bindkey '^[jvj' vars_choose


vars_get() {
  target=$(vars list | sed -n '/^T/p' | cut -d, -f2 | fzy -q ""$1"" -l 20)

  if [[ $? && ! -z $target ]]; then
    BUFFER="vg $target"
    CURSOR=${#BUFFER}
  fi

  zle reset-prompt
}

zle -N vars_get
bindkey '^[jvg' vars_get


vars_run() {
  block=$(vars list | sed -n '/^B/p' | cut -d, -f2 | fzy -q ""$1"" -l 20)

  if [[ $? && ! -z $block ]]; then
    BUFFER="vr $block"
    CURSOR=${#BUFFER}
  fi

  zle reset-prompt
}

zle -N vars_run
bindkey '^[jvr' vars_run


vars_pinArbitrary() {
  var=$(vars list | sed -n '/^T/p' | cut -d, -f2 | fzy -q ""$1"" -l 20)

  if [[ $? && ! -z $var ]]; then
    BUFFER="vp ${var}="
    CURSOR=${#BUFFER}
  fi

  zle reset-prompt
}

zle -N vars_pinArbitrary
bindkey '^[jvp' vars_pinArbitrary


vars_pinFromContext() {
  var=$(vars context list | fzy -q ""$1"" -l 20 | cut -f1)

  if [[ $? && ! -z $var ]]; then
    vars pin $var
  fi

  zle reset-prompt
}

zle -N vars_pinFromContext
bindkey '^[jvxp' vars_pinFromContext


vars_unpin() {
  var=$(vars pin list | fzy -q ""$1"" -l 20 | cut -f1)

  if [[ $? && ! -z $var ]]; then
    vars pin rm $var
  fi

  zle reset-prompt
}

zle -N vars_unpin
bindkey '^[jvpr' vars_unpin


bindkey -s '^[jvpl' 'vars pin list^M'
bindkey -s '^[jvpc' 'vars pin clear^M'

bindkey -s '^[jvx' 'vars context list^M'
bindkey -s '^[jvxl' 'vars context list^M'
bindkey -s '^[jvxc' 'vars context clear^M'

bindkey -s '^[jvxz' 'vars context prev^M'
bindkey -s '^[jvz' 'vars context prev^M'
