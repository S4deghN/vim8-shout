" Define constants
let s:W_THRESHOLD = 160
let s:BUFNAME = '[shout]'

" Define global variables
let s:shout_job = 0
let s:initial_winid = 0

let s:bufnr = -1
let s:follow = 1

let g:shout_count = 0

" Function to determine window split direction based on width
function! Vertical() abort
    let result = ''
    if &columns >= s:W_THRESHOLD && winlayout()[0] !=# 'row'
        let result .= 'vertical'
    endif
    return result
endfunction

" Function to find the window other than the current one
function! FindOtherWin() abort
    let winid = win_getid()
    for wnd in range(1, winnr('$'))
        if win_getid(wnd) !=# winid
            return win_getid(wnd)
        endif
    endfor
    return -1
endfunction

" Function to get the window ID containing '[shout]'
function! ShoutWinId() abort
    for shbuf in getbufinfo()->filter(({_, v -> fnamemodify(v.name, ":t") =~ '^\[shout\]$'}))
        if len(shbuf.windows) > 0
            return shbuf.windows[0]
        endif
    endfor
    return -1
endfunction

function! GetShoutBufnr()
    let buffers = getbufinfo()->filter(({_, v -> fnamemodify(v.name, ":t") == s:BUFNAME}))
    if len(buffers) > 0
        return buffers[0].bufnr
    else
        return -1
    endif
endfunction

" Function to prepare the buffer for output capture
function! PrepareBuffer(shell_cwd) abort
    let winid = OpenWindow()

    call win_gotoid(winid)

    silent :%d _

    let b:shout_cwd = a:shell_cwd
    exe 'silent lcd' a:shell_cwd

    setl undolevels=-1

    return bufnr()
endfunction

" function! FilterOutAnsiAndCarriage(list)
"     return map(a:list, { _, v -> substitute(v, '\e\[[0-9;]*[a-zA-Z]\|\r', '', 'g') })
" endfunction

function! FilterStrings(list, name) abort
    let filtered_list = []
    for str in a:list
        let cleaned_str = substitute(str, '\e\[[0-9;]*[a-zA-Z]\|\r', '', 'g')
        if !empty(cleaned_str)
            call add(filtered_list, cleaned_str)
        endif
    endfor
    return filtered_list
endfunction

let s:out_reminder = ''
function! OnStdout(chan, msg, name)

    let msg = a:msg

    if strlen(s:out_reminder)
        let msg[0] = s:out_reminder .. msg[0]
        let s:out_reminder = ''
    endif

    " If the last strig doesn't end with a \r the line is halved.
    if match(msg[-1], '\r$')
        let s:out_reminder .= msg[-1]
        call remove(msg, -1)
    endif

    " Filter out terminal escape code junk
    " I don't even know how I came up with this especially the second expression. (at
    " least I know that each `\|` is an `or` operator.)
    let msg = map(msg, { _, v -> substitute(v, '\e\[[0-9;]*[a-zA-Z]\|\e\]8;;.\{-}\|\r', '', 'g')})

    call appendbufline(s:bufnr, "$", msg)
    if s:follow
        call win_execute(bufwinid(s:bufnr), "normal! G")
    endif
endfunction

function! OnExit(chan, exit_code, event_type) abort
    if !bufexists(s:bufnr)
        return
    endif

    let winid = bufwinid(s:bufnr)

    if get(g:, "shout_print_exit_code", 1)
        call appendbufline(s:bufnr, line('$', winid), "")
        call appendbufline(s:bufnr, line('$', winid), "Exit code: " .. a:exit_code)
    endif

    if s:follow
        call win_execute(winid, "normal! G")
    endif

    call setbufvar(s:bufnr, "shout_exit_code", string(a:exit_code))
    call win_execute(winid, "setl undolevels&")
endfunction

" Function to capture shell command output
function! CaptureOutput(command) abort
    let cwd = getcwd()
    let s:bufnr = PrepareBuffer(cwd->substitute('#', '\\&', 'g'))

    call setbufvar(s:bufnr, "shout_exit_code", "")

    call setbufline(s:bufnr, 1, '$ ' . a:command)
    call appendbufline(s:bufnr, "$", "")

    if exists('s:shout_job') && s:shout_job > 0
        call jobstop(s:shout_job)
    endif

    let job_command = has('win32') ? a:command : [&shell, &shellcmdflag, escape(a:command, '\')]
    let s:shout_job = jobstart(job_command, {
                \ 'cwd': cwd,
                \ 'pty': 1,
                \ 'rpc': 0,
                \ 'stdout_buffered': 0,
                \ 'stderr_buffered': 0,
                \ 'on_stdout': function('OnStdout'),
                \ 'on_exit': function('OnExit')
                \ })

    let t:shout_cmd = a:command

    if s:follow
        normal! G
    endif

    call win_gotoid(s:initial_winid)
endfunction

sign define ShoutArrow text=→  texthl=Normal
function! SignJumpLine()
    call sign_unplace('Shout', {'id': 1, 'buffer': bufnr()})
    call sign_place(1, 'Shout', 'ShoutArrow', bufnr(), {'lnum': line('.')})
endfunction

function! OpenFile()
    let shout_cwd = get(b:, "shout_cwd", "")
    if !empty(shout_cwd)
        execute "silent lcd" b:shout_cwd
    endif

    " re-run the command if on line 1
    if line('.') == 1
        let cmd = getline(".")->matchstr('^\$ \zs.*$')
        if cmd !~ '^\s*$'
            let pos = getcurpos()
            call CaptureOutput(cmd)
            call setpos('.', pos)
        endif
        return
    endif

    " Windows has : in `isfname` thus for ./filename:20:10: gf can't find filename cause
    " it sees filename:20:10: instead of just filename
    " So the "hack" would be:
    " - take <cWORD> or a line under cursor
    " - extract file name, line, column
    " - edit file name

    " python
    let fname = matchlist(getline('.'), '^\s\+File "\(.\{-}\)", line \(\d\+\)')

    " erlang escript
    if empty(fname)
        let fname = matchlist(getline('.'), '^\s\+in function\s\+.\{-}(\(.\{-}\), line \(\d\+\))')
    endif

    " rust
    if empty(fname)
        let fname = matchlist(getline('.'), '^\s\+--> \(.\{-}\):\(\d\+\):\(\d\+\)')
    endif

    " regular filename:linenr:colnr:
    if empty(fname)
        let fname = matchlist(getline('.'), '^\(.\{-}\):\(\d\+\):\(\d\+\).*')
    endif

    " regular filename:linenr:
    if empty(fname)
        let fname = matchlist(getline('.'), '^\(.\{-}\):\(\d\+\):\?.*')
    endif

    " regular filename:
    if empty(fname)
        let fname = matchlist(getline('.'), '^\(.\{-}\):.*')
    endif

    if len(fname) > 0 && filereadable(fname[1])
        call SignJumpLine()
        try
            let should_split = 0
            let buffers = filter(getbufinfo(), {idx, v -> v.name == fnamemodify(fname[1], ":p")})
            let fname[1] = substitute(fname[1], '#', '\&', 'g')
            " goto opened file if it is visible
            if len(buffers) > 0 && len(buffers[0].windows) > 0
                call win_gotoid(buffers[0].windows[0])
            " goto first non shout window otherwise
            elseif win_gotoid(FindOtherWin())
                if !&hidden && &modified
                    let should_split = 1
                endif
            else
                let should_split = 1
            endif

            execute "lcd ".shout_cwd

            if should_split
                execute "Vertical" "split" fname[1]
            else
                execute "edit" fname[1]
            endif

            if !empty(fname[2])
                execute ":".fname[2]
                execute "normal! 0"
            endif

            if !empty(fname[3]) && str2nr(fname[3]) > 1
                execute "normal! ".(str2nr(fname[3]) - 1)."l"
            endif
            normal! zz
        catch
        endtry
    endif
endfunction

function! Kill()
    if exists('s:shout_job') && s:shout_job != 0
        call jobstop(s:shout_job)
    endif
endfunction

function! CloseWindow()
    let winid = ShoutWinId()
    if winid == -1
        return
    endif
    let winnr = getwininfo(winid)[0].winnr
    exe $":{winnr}close"
endfunction

function! OpenWindow()
    let bufnr = GetShoutBufnr()
    if bufnr < 0
        let bufnr = bufadd(s:BUFNAME)
    endif

    let windows = win_findbuf(bufnr)
    let s:initial_winid = win_getid()

    " TODO: instead of this hack of jumping back find a ways to open the window without jumping to it.
    if len(windows) == 0
        exe 'botright ' . Vertical() . ' sbuffer' bufnr
        setl filetype=shout
        let ret = win_getid()
        call win_gotoid(s:initial_winid)
        return ret
    else
        return windows[0]
    endif
endfunction

function! ShoutToQf()
    let bufnr = GetShoutBufnr()
    if bufnr > 0
        cgetexpr getbufline(bufnr, 1, "$")
    endif
endfunction

function! NextError()
    " Search for python error
    let rxError = '^.\{-}:\d\+\(:\d\+:\?\)\?'
    let rxPyError = '^\s*File ".\{-}", line \d\+,'
    let rxErlEscriptError = '^\s\+in function\s\+.\{-}(.\{-}, line \d\+)'
    call search($'\({rxError}\)\|\({rxPyError}\)\|\({rxErlEscriptError}\)', 'W')
endfunction

function! FirstError()
    " same as `:2`
    execute "2"
    call NextError()
endfunction

function! PrevError()
    let rxError = '^.\{-}:\d\+\(:\d\+:\?\)\?'
    let rxPyError = '^\s*File ".\{-}", line \d\+,'
    let rxErlEscriptError = '^\s\+in function\s\+.\{-}(.\{-}, line \d\+)'
    call search($'\({rxError}\)\|\({rxPyError}\)\|\({rxErlEscriptError}\)', 'bW')
endfunction

function! LastError()
    " same as `:$`
    execute "$"
    call PrevError()
endfunction

function! NextErrorJump()
    if win_gotoid(ShoutWinId())
       execute "normal ]]\<CR>"
    endif
endfunction

function! FirstErrorJump()
    if win_gotoid(ShoutWinId())
       execute "normal [{\<CR>"
    endif
endfunction

function! PrevErrorJump()
    if win_gotoid(ShoutWinId())
       execute "normal [[\<CR>"
    endif
endfunction

function! LastErrorJump()
    if win_gotoid(ShoutWinId())
       execute "normal ]}\<CR>"
    endif
endfunction

" Define other required functions similarly as per the Vim9 script

" Exported functions
"command! -nargs=1 -complete=shellcmd -bar CaptureOutput call CaptureOutput(<f-args>)
command! -nargs=1 -bang -complete=file Sh call CaptureOutput(<f-args>)

command! -nargs=0 -bar ShoutToQf call ShoutToQf()
command! -nargs=0 -bar Shut call CloseWindow()
command! -nargs=0 -bar NotShut call OpenWindow()
command! -nargs=0 -bar OpenFile call OpenFile()
command! -nargs=0 -bar Kill call Kill()
command! -nargs=0 -bar NextError call NextError()
command! -nargs=0 -bar FirstError call FirstError()
command! -nargs=0 -bar PrevError call PrevError()
command! -nargs=0 -bar LastError call LastError()
command! -nargs=0 -bar NextErrorJump call NextErrorJump()
command! -nargs=0 -bar FirstErrorJump call FirstErrorJump()
command! -nargs=0 -bar PrevErrorJump call PrevErrorJump()
command! -nargs=0 -bar LastErrorJump call LastErrorJump()

" TODO: make NextErrorJump and such work even if shout window is not visable
" TODO: some error output by gcc is missinterpreted as jump point by NextError howeve OpenFile is
" fine.
