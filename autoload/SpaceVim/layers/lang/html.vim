function! SpaceVim#layers#lang#html#plugins() abort
  let plugins = [
        \ ['groenewege/vim-less',                    { 'on_ft' : ['less']}],
        \ ['cakebaker/scss-syntax.vim',              { 'on_ft' : ['scss','sass']}],
        \ ['hail2u/vim-css3-syntax',                 { 'on_ft' : ['css','scss','sass']}],
        \ ['ap/vim-css-color',                       { 'on_ft' : ['css','scss','sass','less','styl']}],
        \ ['othree/html5.vim',                       { 'on_ft' : ['html']}],
        \ ['wavded/vim-stylus',                      { 'on_ft' : ['stylus']}],
        \ ['mattn/emmet-vim',                        { 'on_cmd' : 'EmmetInstall'}],
        \ ] 
  return plugins
endfunction

function! SpaceVim#layers#lang#html#config() abort
  let g:user_emmet_leader_key=get(g:, 'user_emmet_leader_key', '<C-e>')
endfunction
