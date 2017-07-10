" Settings related to http://drupal.org/project/vimrc
set nocompatible
" execute pathogen#infect('~/.vim/bundle/drupalvim/bundle')
execute pathogen#infect()
syntax on
filetype plugin indent on
" End of drupal/vimrc
" source $VIMRUNTIME/vimrc_example.vim
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
" Show the command being entered
set showcmd

" Allow local overrides in ~/.vimrc_local
let $LOCALFILE=expand("~/.vimrc_local")
if filereadable($LOCALFILE)
    source $LOCALFILE
endif
