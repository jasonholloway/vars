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
    O)
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
bindkey '^[vl' vars_choose
bindkey 'jvl' vars_choose


vars_get() {
  targets=$(vars ls 2)

  var=$(echo "$targets" | awk -F, '/^O/ { print $2 }' | fzy -q ""$1"" -l 20)

  read dir target <<<"$(echo "$targets" | awk -F, '/^O/ && $2 == "'$var'" { print $3 " " $7 }')"

  shortDir=$(realpath --relative-to=$PWD $dir)

  if [[ $? && ! -z $target ]]; then
    BUFFER="(cd $shortDir && vg $target)"
    CURSOR=${#BUFFER}
    zle accept-line
  fi

  zle reset-prompt
}

zle -N vars_get
bindkey '^[jvg' vars_get
bindkey '^[vg' vars_get
bindkey 'jvg' vars_get


vars_run() {
  targets=$(vars ls 2)

  block=$(echo "$targets" | awk -F, '/^B/ { print $2 }' | fzy -q ""$1"" -l 20)

  read dir target <<<"$(echo "$targets" | awk -F, '/^B/ && $2 == "'$block'" { print $3 " " $7 }')"

  shortDir=$(realpath --relative-to=$PWD $dir)

  if [[ $? && ! -z $target ]]; then
    BUFFER="(cd $shortDir && vr $target)"
    CURSOR=${#BUFFER}
    zle accept-line
  fi

  zle reset-prompt
}

zle -N vars_run
bindkey '^[jvr' vars_run
bindkey '^[vr' vars_run
bindkey 'jvr' vars_run


vars_pinArbitrary() {
  # var=$(vars list | sed -n '/^I/p' | cut -d, -f2 | fzy -q ""$1"" -l 20)

  targets=$(vars ls 2)

  var=$(echo "$targets" | awk -F, '/^I/ { print $7 }' | sort | uniq | fzy -q ""$1"" -l 20)

  # read dir target <<<"$(echo "$targets" | awk -F, '/^I/ && $2 == "'$var'" { print $3 " " $7 }')"

  # shortDir=$(realpath --relative-to=$PWD $dir)

  if [[ $? && ! -z $var ]]; then
    BUFFER="vp ${var}="
    CURSOR=${#BUFFER}
  fi

  zle reset-prompt
}

zle -N vars_pinArbitrary
bindkey '^[jvp' vars_pinArbitrary
bindkey '^[vp' vars_pinArbitrary
bindkey 'jvp' vars_pinArbitrary


vars_pinFromContext() {
  var=$(vars context list | tac | fzy -q ""$1"" -l 20)

  if [[ $? && ! -z $var ]]; then
    vars pin $var
  fi

  zle reset-prompt
}

zle -N vars_pinFromContext
bindkey '^[jvxp' vars_pinFromContext
bindkey '^[vxp' vars_pinFromContext
bindkey 'jvxp' vars_pinFromContext


vars_unpin() {
  var=$(vars pin list | fzy -q ""$1"" -l 20 | cut -f1)

  if [[ $? && ! -z $var ]]; then
    vars pin rm $var
  fi

  zle reset-prompt
}

zle -N vars_unpin
bindkey '^[jvpr' vars_unpin
bindkey '^[vpr' vars_unpin
bindkey 'jvpr' vars_unpin


bindkey -s '^[jvpl' 'vars pin list^M'
bindkey -s '^[jvpc' 'vars pin clear^M'

bindkey -s '^[jvx' 'vars context list^M'
bindkey -s '^[jvxl' 'vars context list^M'
bindkey -s '^[jvxc' 'vars context clear^M'

bindkey -s '^[jvxz' 'vars context prev^M'
bindkey -s '^[jvz' 'vars context prev^M'


bindkey -s '^[vpl' 'vars pin list^M'
bindkey -s '^[vpc' 'vars pin clear^M'

bindkey -s '^[vx' 'vars context list^M'
bindkey -s '^[vxl' 'vars context list^M'
bindkey -s '^[vxc' 'vars context clear^M'

bindkey -s '^[vxz' 'vars context prev^M'
bindkey -s '^[vz' 'vars context prev^M'


bindkey -s 'jvpl' 'vars pin list^M'
bindkey -s 'jvpc' 'vars pin clear^M'

bindkey -s 'jvx' 'vars context list^M'
bindkey -s 'jvxl' 'vars context list^M'
bindkey -s 'jvxc' 'vars context clear^M'

bindkey -s 'jvxz' 'vars context prev^M'
bindkey -s 'jvz' 'vars context prev^M'
