#!/bin/bash

if test -e vader.vim
then vader_rtp='vader.vim'
else vader_rtp='../vader.vim'
fi

vim -Nu <(printf 'set rtp+=%s\n' "$vader_rtp" '.') -c 'Vader! test/*' >/dev/null
