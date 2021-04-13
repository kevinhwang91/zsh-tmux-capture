# tmux-capture

Tmux capture content produced by command of zsh.

[![asciicast](https://asciinema.org/a/360605.svg)](https://asciinema.org/a/360605)

## Table of contents

* [Table of contents](#table-of-contents)
* [Requirements](#requirements)
* [Features](#features)
* [Installation](#installation)
  * [Manual](#manual)
  * [Zgen](#zgen)
  * [Zinit](#zinit)
* [Usage](#usage)
  * [Inspect last scrolled command](#inspect-last-scrolled-command)
  * [Insert content to ZLE](#insert-content-to-zle)
  * [Suggestion](#suggestion)
* [Custom](#custom)
  * [Zsh variables](#zsh-variables)
  * [Zsh hooks](#zsh-hooks)
  * [Simple custom example](#simple-custom-example)
  * [Advanced custom example](#advanced-custom-example)
* [FAQ](#faq)
* [License](#license)

## Requirements

1. zsh
2. [tmux](https://github.com/tmux/tmux) (**3.2 or later**)

## Features

- Inspect content produced by last scrolled command quickly
- Insert content produced by the lastest command

## Installation

### Manual

1. Get the source code `git clone https://github.com/kevinhwang91/zsh-tmux-capture.git`
2. Insert `source your_path/zsh-tmux-capture/tmux-capture.plugin.zsh`
   to your `~/.zshrc`

### Zgen

`zgen load 'kevinhwang91/zsh-tmux-capture'`

### Zinit

`zinit light kevinhwang91/zsh-tmux-capture`

## Usage

### Inspect last scrolled command

1. In zsh, using `ctrl+o(^O)` to jump to the beginning line produced by last scrolled command;
2. If scrolled command is captured, you will enter `copy-mode` in tmux, cursor will be in the
   beginning line of the content;
3. You can use your own `copy-mode` keys, and there are two additional keys to jump 'boundary':
   1. `ctrl+o(C-o)`: go to the top line produced by last scrolled command.
   2. `ctrl+g(C-g)`: go to the bottom line.

### Insert content to ZLE

1. In zsh, using `alt+o(^[o)` to append content produced by the lastest command to `LBUFFER`.

### Suggestion

1. tmux capture content from history, please increase the `history-limit` to get better experience.

## Custom

### Zsh variables

Feel free to assign the below variables to the values what you want:

- TMUX_CP_MODE_STYLE_ERR: tmux option for `mode-style` when return code of the last captured
  command is not zero. default value is `fg=black,bg=red`.
- TMUX_CP_MODE_STYLE_SUC: tmux option for `mode-style` when return code of the last captured
  command is zero. default value is `fg=black,bg=green`.
- TMUX_CP_BK_TOP_L: bind key to go to top line of captured content in copy mode.
  default value is `C-o`.
- TMUX_CP_BK_BOT_L: bind key to go to bottom line of captured content in copy mode.
  default value is `C-g`.

ReadOnly variable:

- TMUX_CP_RET: return code of the lastest captured command, only be used inside
  `tmux-capture-notify`. Check out [Advanced custom example](#advanced-custom-example) for detail.
- TMUX_CP_PROMPT: return 1 if captured content for lastest command, otherwise unset this variable,
  only be used for `PROMPT`. Check out [Advanced custom example](#advanced-custom-example) for detail.

### Zsh hooks

There're two hooks export to the users, their trigger times:

1. `tmux-capture-notify`: Trigger after scrolled command is captured, use this hook as callback.
2. `tmux-capture-enter-mode`: Triggering after initializing `copy-mode` for scrolled content.

### Simple custom example

```zsh
# remap ^O to ^T in zsh
zle -N tmux-capture-last-scrolled
bindkey '^T' tmux-capture-last-scrolled

# remap ^[o to ^[j in zsh
zle -N insert-last-cmd-out
bindkey '^[j' insert-last-cmd-out

TMUX_CP_MODE_STYLE_ERR='fg=black,bg=magenta'
TMUX_CP_MODE_STYLE_SUC='fg=black,bg=cyan'

TMUX_CP_BK_TOP_L='C-t'
TMUX_CP_BK_BOT_L='C-b'

source your_path/zsh-tmux-capture/tmux-capture.plugin.zsh
```

### Advanced custom example

```zsh
tmux-capture-notify() {
    # You can append $TMUX_CP_CMD to a log file to decide the value of $TMUX_CP_WHITE_PATTERN
    # print $TMUX_CP_CMD >> ~/.tmux_capture_log
    if (( ! $TMUX_CP_RET )) && [[ $TMUX_CP_CMD =~ $TMUX_CP_WHITE_PATTERN ]]; then
        # Enter copy-mode immediately
        tmux-capture-last-scrolled
    fi
}

tmux-capture-enter-mode() {
    # Make curosr jump to bottom line of current view
    tmux send -t $TMUX_PANE -X bottom-line
}

_tmux_capture_export_cmd() {
    TMUX_CP_CMD=$2
}

autoload -U add-zsh-hook
add-zsh-hook preexec _tmux_capture_export_cmd

# Add grep and ps to whitelist
TMUX_CP_WHITE_PATTERN='(grep|^ps)'

# Customize prompt and add underline for path when captured content
_prompt() {
    if (( TMUX_CP_PROMPT)); then
        print -n %U
    fi

    print -n %d

    if (( TMUX_CP_PROMPT)); then
        print -n %u
    fi
    print -n ' '
}

setopt prompt_subst
PROMPT='$(_prompt)'

source your_path/zsh-tmux-capture/tmux-capture.plugin.zsh
```

## FAQ

Q: Why this plugin is not supported before tmux 3.2?

A: This plugin needs [e0b17e](https://github.com/tmux/tmux/commit/e0b17e796b52bfad7d867bc876a9826bf5761be4)
to get `#{buffer_name}` after invoking `capture-pane`.
Compatibility with older versions is not the goal of this plugin.

Q: Why don't you use `LBUFFER+=$(eval $history[$(( HISTCMD-1 ))])` to insert the output of the last command?

A: It only gets last history command and then get `stdout` by executing command again, which can't
capture stdout of interactive command like `fzf`.

## License

The project is licensed under a BSD-3-clause license. See [LICENSE](./LICENSE) file for details.
