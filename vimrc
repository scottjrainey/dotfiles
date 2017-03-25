" Following lines added by drush vimrc-install on Wed, 30 Apr 2014 20:50:23 +0000.
" set nocompatible
" call pathogen#infect('/Users/srainey/.drush/vimrc/bundle')
" call pathogen#infect('/Users/srainey/.vim/bundle')
" End of vimrc-install additions.
source $VIMRUNTIME/vimrc_example.vim
" Powerline
set rtp+=/Users/srainey/Library/Python/2.7/lib/python/site-packages/powerline/bindings/vim
python from powerline.vim import setup as powerline_setup
python powerline_setup()
python del powerline_setup
" Line numbering
set number relativenumber
