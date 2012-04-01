let s:ParaListStack = []
let s:FlagStack = []

let s:MatchPairs = { ')':'(', '}':'{', ']':'[', '>':'<', "'":"'", "\"":"\""}

" DEBUG
function! DebugEcho(variable)
    return eval("s:".a:variable)
endfunction

function! IsEchoMode(punc)
    if empty(s:FlagStack)
        return 0
    else
        if (a:punc == 'comma') && (s:FlagStack[-1] != 'i')
            return 0
        else
            return 1
        endif
    endif
endfunction

function! AddRemoveFlag(flag)
    if get(s:FlagStack, -1) !~ "[\"\']"
        if a:flag =~ "[([{<'\"]"
            call add(s:FlagStack, a:flag)
        elseif a:flag =~ "[)}>\\]]"
            if s:MatchPairs[a:flag] == s:FlagStack[-1]
                call remove(s:FlagStack, -1)
            endif
        else
            " echo error
        endif
    else
        if s:MatchPairs[a:flag] == s:FlagStack[-1]
            call remove(s:FlagStack, -1)
        endif
    endif

    return a:flag
endfunction

function! CallTagList(str)
    let ftags = []
    try
        let ftags=taglist(a:str)
    catch /^Vim\%((\a\+)\)\=:E/
        " if error occured, reset tagbsearch option and try again.
        let bak=&tagbsearch
        set notagbsearch
        let ftags=taglist(a:str)
        let &tagbsearch=bak
    endtry
    return ftags
endfunction

function! GetFuncName(text)
    let name=substitute(a:text,'.\{-}\(\(\k\+::\)*\(\~\?\k*\|'.
                \'operator\s\+new\(\[]\)\?\|'.
                \'operator\s\+delete\(\[]\)\?\|'.
                \'operator\s*[[\]()+\-*/%<>=!~\^&|]\+'.
                \'\)\)\s*$','\1','')
    if name =~ '\<operator\>'  " tags have exactly one space after 'operator'
        let name=substitute(name,'\<operator\s*','operator ','')
    endif
    return name
endfunction

function! GetParameterList(functag)
    let declaration = a:functag['cmd']
    let parameters = substitute(declaration, '\/\^.\{-}\(\k\+::\)*\~\?\k*(\(.\{-}\)):\$\/', '\2', "")
    let paralist = split(parameters, '\s*,\s*')

    return paralist
endfunction

function! SelectWord(word)
    let col = match(getline('.'), a:word) + 1
    call cursor(line('.'), col)
    exec 'normal v'.(strlen(a:word) - 1)."l\<c-g>"
endfunction

function! JumpToNextParameter()
    let paralist = s:ParaListStack[-1]

    call SelectWord(paralist[0])
    call remove(paralist, 0)
    if empty(paralist)
        call ExitEchoMode()
    endif
endfunction

function! EncloseFunction()

endfunction

function! ExpandParameters(paralist)
    call setline('.', getline('.').join(a:paralist, ", ").")")
endfunction

function! EnterEchoMode()
    let funcname = GetFuncName(getline('.')[:(col('.')-2)])
    let funcpat = escape(funcname, "[\*~^")
    let functagS = CallTagList("^".funcpat.'$')

    " ProtoType
    if empty(s:FlagStack)
        call add(s:FlagStack, '(')
    endif
    call add(s:FlagStack, 'i')
    let paralist = GetParameterList(functagS[0])
    call ExpandParameters(paralist)
    call add(s:ParaListStack, paralist)
    call JumpToNextParameter()
endfunction

function! ExitEchoMode()
    call remove(s:ParaListStack, -1)
    " find 'i' from rear and remove it along with previous bracket
    while s:FlagStack[-1] != 'i'
        call remove(s:FlagStack, -1)
    endwhile
    call remove(s:FlagStack, -1)
    call remove(s:FlagStack, -1)
endfunction

function! AbortEchoMode()
endfunction

" ProtoType
inoremap <F5> <C-O>:call EnterEchoMode()<CR>
inoremap <expr>, IsEchoMode('comma') ? "<C-O>:<C-U>call JumpToNextParameter()<CR>" : ','
inoremap <expr>[ IsEchoMode('brackets') ? "<C-R>=AddRemoveFlag('[')<CR>" : '['
inoremap <expr>] IsEchoMode('brackets') ? "<C-R>=AddRemoveFlag(']')<CR>" : ']'
inoremap <expr>( IsEchoMode('brackets') ? "<C-R>=AddRemoveFlag('(')<CR>" : '('
inoremap <expr>) IsEchoMode('brackets') ? "<C-R>=AddRemoveFlag(')')<CR>" : ')'
inoremap <expr>{ IsEchoMode('brackets') ? "<C-R>=AddRemoveFlag('{')<CR>" : '{'
inoremap <expr>} IsEchoMode('brackets') ? "<C-R>=AddRemoveFlag('}')<CR>" : '}'
inoremap <expr>" IsEchoMode('quota') ? '<C-R>=AddRemoveFlag("\"")<CR>' : '"'
inoremap <expr>' IsEchoMode('quota') ? "<C-R>=AddRemoveFlag(\"\\'\")<CR>" : "\'"
