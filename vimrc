" Following lines added by drush vimrc-install on Wed, 30 Apr 2014 20:50:23 +0000.
" set nocompatible
" call pathogen#infect('/Users/srainey/.drush/vimrc/bundle')
" call pathogen#infect('/Users/srainey/.vim/bundle')
" End of vimrc-install additions.
source $VIMRUNTIME/vimrc_example.vim
" Powerline
set rtp+=$HOME/.local/lib/python/site-packages/powerline/bindings/vim/
" always show statusline
set laststatus=2
set t_Co=256
" python3 from powerline.vim import setup as powerline_setup
" python3 powerline_setup()
" python3 del powerline_setup
" Line numbering
set number relativenumber

" Allow local overrides in ~/.vimrc_local
let $LOCALFILE=expand("~/.vimrc_local")
if filereadable($LOCALFILE)
    source $LOCALFILE
endif
