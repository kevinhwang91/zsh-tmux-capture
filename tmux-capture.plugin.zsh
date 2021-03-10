#!/usr/bin/env zsh

if (( ! $+commands[tmux] )) || [[ -z $TMUX_PANE ]] || [[ ! $- =~ i ]]; then
    return
fi

_tmux_capture_preexec() {
    local info=(${(z)$(tmux display -t $TMUX_PANE -p '#{history_size} #{cursor_y}')})
    local hist_size=$info[1]
    local cursor_y=$info[2]
    typeset -g _tmux_cp_last_range=$(( hist_size + cursor_y ))
    typeset -g _tmux_cp_sample=$(tmux capturep -t $TMUX_PANE -p \
        -S $(( cursor_y - 8 )) -E $(( cursor_y - 4 )))
}

_tmux_capture_defer_handler() {
    trap '_tmux_capture_clear_context' EXIT

    zle -F $1
    exec {1}>&-

    if (( ! _tmux_cp_last_range )); then
        return
    fi

    local info=(${(z)$(tmux display -t $TMUX_PANE -p \
        '#{history_size} #{cursor_y} #{e|/|:#{history_limit},10}')})
    local hist_size=$info[1]
    local cursor_y=$info[2]
    local hist_inc=$info[3]
    local cur_range=$(( hist_size + cursor_y ))
    local offset=$(( cur_range - _tmux_cp_last_range ))

    local sample
    while (( _tmux_cp_last_range >= 0 )); do
        sample=$(tmux capturep -p -t $TMUX_PANE \
            -S $(( cursor_y - 8 - offset )) -E $(( cursor_y - 4 - offset )))

        if [[ $sample == $_tmux_cp_sample ]]; then
            break
        fi
        offset=$(( cur_range - _tmux_cp_last_range ))
        _tmux_cp_last_range=$(( _tmux_cp_last_range - hist_inc ))
    done

    if (( _tmux_cp_last_range < 0 )); then
        unset _tmux_cp_offset
        unset _tmux_cp_range
        unset TMUX_CP_RET
        return
    fi

    _tmux_last_output $cursor_y $offset

    if (( offset >= LINES )); then
        typeset -g _tmux_cp_offset=$offset
        typeset -g _tmux_cp_range=$cur_range
        TMUX_CP_RET=$_tmux_cp_last_code
        TMUX_CP_PROMPT=1
        if (( $+functions[tmux-capture-notify] )); then
            tmux-capture-notify
        fi
        zle reset-prompt
    fi
}

_tmux_capture_precmd() {
    typeset -g _tmux_cp_last_code=$?

    unset TMUX_CP_PROMPT
    if [[ -z $_tmux_cp_last_range ]]; then
        return
    fi

    # can't get history_size properly when pane is unzoomed
    # let's defer 100ms to wait tmux flush history_size :)
    local fd
    zmodload zsh/zselect
    exec {fd}< <(zselect -t 10)

    zle -F $fd _tmux_capture_defer_handler
}

_tmux_capture_clear_context() {
    unset _tmux_cp_sample
    unset _tmux_cp_last_range
    unset _tmux_cp_last_code
}

_tmux_last_output() {
    local cursor_y=$1
    local offset=$2
    typeset -g _tmux_cp_last_buf
    if (( offset )); then
        tmux capturep -t $TMUX_PANE -J -S $(( cursor_y - offset )) -E $(( cursor_y - 1 ))
        _tmux_cp_last_buf=$(tmux display -t $TMUX_PANE -p '#{buffer_name}')
    else
        _tmux_cp_last_buf=
    fi
}

tmux-capture-last-scrolled() {
    if [[ -z $TMUX_CP_RET ]]; then
        tmux display 'never captured scrolled message in #{pane_tty}' &|
        return
    fi
    if (( TMUX_CP_PROMPT )); then
        unset TMUX_CP_PROMPT
        zle reset-prompt
    fi

    local hist_size=$(tmux display -t $TMUX_PANE -p '#{history_size}')
    local top_line=$(( _tmux_cp_offset + hist_size - _tmux_cp_range ))
    local bottom_line=$(( LINES + hist_size - _tmux_cp_range ))

    if (( TMUX_CP_RET )); then
        local mode_style=${TMUX_CP_MODE_STYLE_ERR:-'fg=black, bg=red'}
    else
        local mode_style=${TMUX_CP_MODE_STYLE_SUC:-'fg=black, bg=green'}
    fi

    tmux set -w -t $TMUX_PANE mode-style $mode_style \; \
        copy-mode -t $TMUX_PANE \; \
        bind -T copy-mode-vi ${TMUX_CP_BK_TOP_L:-C-o} "
            send -t $TMUX_PANE -X goto-line $top_line;
            send -t $TMUX_PANE -X top-line" \; \
        bind -T copy-mode-vi ${TMUX_CP_BK_BOT_L:-C-g} "
            send -t $TMUX_PANE -X goto-line $bottom_line;
            send -t $TMUX_PANE -X bottom-line" \; \
        send -t $TMUX_PANE -X goto-line $top_line \; \
        send -t $TMUX_PANE -X top-line
    tmux set-hook -p -t $TMUX_PANE 'pane-mode-changed[20]' "
        unbind -T copy-mode-vi ${TMUX_CP_BK_TOP_L:-C-o};
        unbind -T copy-mode-vi ${TMUX_CP_BK_BOT_L:-C-g};
        set -t $TMUX_PANE -uw mode-style;
        set-hook -up -t $TMUX_PANE pane-mode-changed[20]"

    if (( $+functions[tmux-capture-enter-mode] )); then
        tmux-capture-enter-mode
    fi
}

insert-last-cmd-out() {
    if [[ -n $_tmux_cp_last_buf ]]; then
        local last_out
        last_out=$(tmux show-buffer -b $_tmux_cp_last_buf 2>/dev/null)
        if (( ? )); then
            LBUFFER+=$(eval $history[$(( HISTCMD-1 ))])
        else
            setopt localoptions extendedglob
            local lines=()
            for line in "${(@f)last_out}"; do
                lines+=${line%% #}
            done
            LBUFFER+=${(F)lines}
        fi
    fi
}

autoload -U add-zsh-hook
add-zsh-hook preexec _tmux_capture_preexec
add-zsh-hook precmd _tmux_capture_precmd

if (( ! $+widgets[tmux-capture-last-scrolled] )); then
    zle -N tmux-capture-last-scrolled
    bindkey '^O' tmux-capture-last-scrolled
fi

if (( ! $+widgets[insert-last-cmd-out] )); then
    zle -N insert-last-cmd-out
    bindkey '^[o' insert-last-cmd-out
fi
