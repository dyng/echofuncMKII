let s:ParaListStack = []
let s:FlagStack = []

function! IsEchoMode()
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
    let col = match(getline("."), a:word) + 1
    call cursor(line("."), col)
    exec "normal v".(strlen(a:word) - 1)."l\<c-g>"
endfunction

function! SelectParameter(paralist)
    if !empty(a:paralist)
        call SelectWord(a:paralist[0])
        call remove(a:paralist, 0)
        return 1
    else
        " ProtoType
    endif
endfunction

function! JumpToNextParameter()
    call SelectParameter(s:ParaListStack[-1]) " ProtoType
endfunction

function! ExpandParameters(paralist)
    call setline(".", getline(".").join(a:paralist, ", ").")")
endfunction

function! EnterEchoMode()
    let funcname = GetFuncName(getline(".")[:(col(".")-2)])
    let funcpat = escape(funcname, "[\*~^")
    let functagS = CallTagList("^".funcpat.'$')

    " ProtoType
    let paralist = GetParameterList(functagS[0])
    call ExpandParameters(paralist)
    call add(s:ParaListStack, paralist)
    call JumpToNextParameter()
endfunction

" ProtoType
imap <F5> <C-O>:call EnterEchoMode()<CR>
imap , <C-O>:call JumpToNextParameter()<CR>
