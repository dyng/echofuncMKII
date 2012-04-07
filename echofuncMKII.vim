" TODO
" Add a function for ) : call EncloseFunction and AddRemoveFlag
"
" TODO
" 1. paralist selectable
" 2. automatic update tagfile (collabrate with taglist)
" 3. omnifunction for echo patern

let s:MatchPairs = { ')':'(', '}':'{', ']':'[', '>':'<', "'":"'", "\"":"\""}

" TODO change delimiter to a buffer variable
" here is a global variable for prototype
let g:delimiter = ','

" DEBUG
function! DebugEcho(variable)
    return eval("s:".a:variable)
endfunction

function! Initiate()
    if !exists("b:ParaListStack")
        let b:ParaListStack = []
    endif
    if !exists("b:FlagStack")
        let b:FlagStack = []
    endif
    if empty(b:FlagStack)
        call add(b:FlagStack, '(')
    endif
endfunction

function! AddRemoveFlag(flag)
    if get(b:FlagStack, -1) !~ "[\"\']"
        if a:flag =~ "[([{<'\"]"
            call add(b:FlagStack, a:flag)
        elseif a:flag =~ "[)}>\\]]"
            if s:MatchPairs[a:flag] == b:FlagStack[-1]
                call remove(b:FlagStack, -1)
            endif
        endif
    else
        " if flag is d'quotation or s'quotation then remove last flag
        " because last flag is assumed to be d'quotation or s'quotation
        if s:MatchPairs[a:flag] == b:FlagStack[-1]
            call remove(b:FlagStack, -1)
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
    " TODO Need to support more language
    " Current : Vim, Python
    let parameters = substitute(declaration, '\/\^.\{-}\(\k\+::\)*\~\?\k*(\(.\{-}\)):\?\$\/', '\2', "")
    let paralist = split(parameters, '\s*'.g:delimiter.'\s*')
    return paralist
endfunction

function! SelectWord(word)
    let col = match(getline('.'), a:word, col('.')) + 1
    call cursor(line('.'), col)
    return "\<c-c>lv".(strlen(a:word) - 1)."l\<c-g>"
endfunction

function! NextParameter(trigger)
    if !empty(b:ParaListStack) && b:FlagStack[-1] == 'i'
        let paralist = b:ParaListStack[-1]
        let word = paralist[0]
        call remove(paralist, 0)
        if empty(paralist)
            call ExitEchoMode()
        endif
        return SelectWord(word)
    else
        return a:trigger
    endif
endfunction

function! EncloseFunction()
    if !empty(b:ParaListStack[-1])
        let cmd = "\<c-c>f".g:delimiter."dt)a"
    else
        let cmd = "\<c-c>f)a"
    endif
    call ExitEchoMode()
    return cmd
endfunction

function! ExpandParameters(paralist)
    " TODO There is a bug in the situation that cursor is in the middle of line
    " Consider place the cursor at where
    call setline('.', getline('.').join(a:paralist,  g:delimiter." ").")")
endfunction

function! EnterEchoMode()
    call Initiate()

    let funcname = GetFuncName(getline('.')[:(col('.')-3)])
    let funcpat = escape(funcname, "[\*~^")
    let functagS = CallTagList("^".funcpat.'$')

    call add(b:FlagStack, 'i')
    let paralist = GetParameterList(functagS[0])
    if !empty(paralist)
        call ExpandParameters(paralist)
        call add(b:ParaListStack, paralist)
        return NextParameter("")
    else
        return ")"
    endif
endfunction

function! ExitEchoMode()
    " Pop latest function's paralist from stack
    call remove(b:ParaListStack, -1)
    " Find 'i' from rear and remove it along with previous bracket
    while b:FlagStack[-1] != 'i'
        call remove(b:FlagStack, -1)
    endwhile
    " Pop '(' and 'i'
    call remove(b:FlagStack, -2, -1)
endfunction

function! AbortEchoMode()
    let b:ParaListStack = []
    let b:FlagStack = []
endfunction

" TODO Add smap
" ProtoType
inoremap <F6> <C-R>=EnterEchoMode()<CR>
inoremap , <C-R>=NextParameter(',')<CR>
snoremap , <C-C>a<C-R>=NextParameter(',')<CR>
inoremap ) <C-R>=EncloseFunction()<CR>
snoremap ) <C-C>a<C-R>=EncloseFunction()<CR>
inoremap ( <C-R>=AddRemoveFlag('(')<CR>
inoremap [ <C-R>=AddRemoveFlag('[')<CR>
inoremap ] <C-R>=AddRemoveFlag(']')<CR>
inoremap { <C-R>=AddRemoveFlag('{')<CR>
inoremap } <C-R>=AddRemoveFlag('}')<CR>
inoremap " <C-R>=AddRemoveFlag('"')<CR>
inoremap ' <C-R>=AddRemoveFlag('\'')<CR>
