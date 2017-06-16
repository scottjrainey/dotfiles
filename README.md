scottjrainey/dotfiles
=====================

Based on an excellent [blog post][blog-post] by Anish Athalye.

After cloning this repo, run `install` to automatically set up the development
environment. Note that the install script is idempotent: it can safely be run
multiple times.

Dotfiles uses [Dotbot][dotbot] for installation.

Configurations
--------------

Configurations are included for the following programs:

* `byobu`
* `git`
* `oh-my-zsh`
* `vim`
* `zsh`

Making Local Customizations
---------------------------

You can make local customizations for some programs by editing these files:

* `vim` : `~/.vimrc_local`
* `zsh` : `~/.zshrc_local`
* `git` : `~/.gitconfig_local`

License
-------

Copyright (c) 2017 Scott Rainey. Released under the MIT License. See
[LICENSE.md][license] for details.

[blog-post]: http://www.anishathalye.com/2014/08/03/managing-your-dotfiles
[dotbot]: https://github.com/anishathalye/dotbot
[license]: LICENSE.md
