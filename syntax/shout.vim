if exists("b:current_syntax")
    finish
endif

syntax match shoutCmdPrompt "\%^$"
syntax match shoutExitCodeErr "^Exit code: .*\%$"
syntax match shoutExitCodeNoErr "^Exit code: 0\%$"

syntax match shoutCargoPath "-->\s\+.\{-}:\d\+:\d\+" contains=shoutCargoPathNr
syntax match shoutCargoPathNr ":\d\+:\d\+" contained

syntax match shoutGrepPath "^\S.\{-}\S:\(\d\+:\)\{1,2}" contains=shoutGrepPathNr
syntax match shoutGrepPathNr ":\(\d\+:\)\{1,2}" contained

syntax match shoutPythonLocation '^\s\+File ".\{-}", line \d\+' contains=shoutPythonPath,shoutPythonNr
syntax match shoutPythonPath 'File "\zs.\{-}\ze"' contained
syntax match shoutPythonNr "line \zs\d\+" contained

syntax match shoutError "\c^\s*error:\ze " nextgroup=shoutMsg
syntax match shoutWarning "\c^\s*warning:\ze " nextgroup=shoutMsg
syntax match shoutSpecialInfo '^\s\+Compiling\|Finished\|Running\s\+' nextgroup=shoutMsg
syntax match shoutMsg ".*$" contained

" Erlang escript
syntax region shoutError matchgroup=shoutError start="^escript:" matchgroup=shoutMsg end="errors.$" contains=shoutMsg oneline
syntax region shoutError matchgroup=shoutError start="^escript: exception error:" end="$" contains=shoutMsg oneline keepend
syntax match shoutLocation '^\s\+in function\s\+.\{-}(.\{-}, line \d\+)' contains=shoutPath,shoutNr
syntax match shoutPath '(\zs.\{-}\ze, ' contained
syntax match shoutNr "line \zs\d\+" contained

syntax match shoutTexWarning '^Underfull \[hv]box (badness \d\+).*$'
syntax match shoutTexError '^\s*==> .* <==$'

syntax match shoutTodo "\<\(TODO\|FIXME\|XXX\):"

syntax match shoutLogDebug "\<\(TRACE\|trace\|DEBUG\|debug\|note\)\>"
syntax match shoutLogInfo  "\<\(INFO\|info\)\>"
syntax match shoutLogWarn  "\<\(WARN\|warn\|warning\)\>"
syntax match shoutLogError "\<\(ERROR\|error\)\>"

hi link shoutLogInfo String
hi link shoutLogWarn WarningMsg
hi link shoutLogError ErrorMsg
hi link ShoutLogDebug Comment

hi link shoutCmdPrompt Statement
hi link shoutPath String
hi link shoutNr Constant

hi link shoutCargoPath String
hi link shoutCargoPathNr Constant
hi link shoutGrepPath String
hi link shoutGrepPathNr Constant
hi link shoutPythonPath String
hi link shoutPythonNr Constant

hi link shoutError ErrorMsg
hi link shoutWarning WarningMsg
hi link shoutMsg Title
hi link shoutSpecialInfo PreProc

hi link shoutExitCodeNoErr Comment
hi link shoutExitCodeErr WarningMsg

hi link shoutTexWarning WarningMsg
hi link shoutTexError ErrorMsg

hi link shoutTodo Todo

let b:current_syntax = "shout"
