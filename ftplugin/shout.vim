if exists("b:did_ftplugin")
    finish
endif

let b:did_ftplugin = 1

setlocal nocursorline
setlocal cursorlineopt=both
setlocal bufhidden=hide
setlocal buftype=nofile
setlocal buflisted
setlocal noswapfile
setlocal noundofile
setlocal signcolumn=yes
let b:shout_exit_code = 0
setlocal stl=[shout]\ -\ %(%{%expand(t:shout_cmd)%}%)\ -\ %(%{%expand(b:shout_exit_code)%}%)%=\ \ \ \ %-8(%l,%c%)\ %P

let b:undo_ftplugin = 'setlocal cursorline< cursorlineopt< bufhidden< buftype< buflisted< swapfile< undofile<'
let b:undo_ftplugin .= '| exe "nunmap <buffer> <CR>"'
let b:undo_ftplugin .= '| exe "nunmap <buffer> <C-c>"'
let b:undo_ftplugin .= '| exe "nunmap <buffer> ]]"'
let b:undo_ftplugin .= '| exe "nunmap <buffer> [["'
let b:undo_ftplugin .= '| exe "nunmap <buffer> ]}"'
let b:undo_ftplugin .= '| exe "nunmap <buffer> [{"'
let b:undo_ftplugin .= '| exe "nunmap <buffer> gq"'

nnoremap <buffer> <CR> :OpenFile<CR>
nnoremap <buffer> <C-c> :Kill<CR><C-c>
nnoremap <buffer> ]] :NextError<CR>
nnoremap <buffer> [[ :PrevError<CR>
nnoremap <buffer> [{ :FirstError<CR>
nnoremap <buffer> ]} :LastError<CR>
nnoremap <buffer> gq <C-w>c
