" Header Section {{{1
" =============================================================================
" File:          plugin/markify.vim
" Description:   Use sign to mark & indicate lines matched by quickfix
"                commands. Works for  :make, :lmake, :grep, :lgrep, :grepadd,
"                :lgrepadd, :vimgrep, :lvimgrep, :vimgrepadd, :lvimgrepadd,
"                :cscope, :helpgrep, :lhelpgrep
" Author:        Dhruva Sagar <http://dhruvasagar.com/>
" License:       Vim License
" Website:       http://github.com/dhruvasagar/vim-markify
" Version:       1.1.1
"
" Copyright Notice:
"                Permission is hereby granted to use and distribute this code,
"                with or without modifications, provided that this copyright
"                notice is copied with it. Like anything else that's free,
"                marify.vim is provided *as is* and comes with no warranty of
"                any kind, either expressed or implied. In no event will the
"                copyright holder be liable for any damamges resulting from
"                the use of this software.
" =============================================================================
" }}}1

if exists('g:markify_loaded') "{{{1
  finish
endif
let g:markify_loaded = 1
" }}}1

if !has('signs') "{{{1
  echoerr 'Compile VIM with signs to use this plugin.'
  finish
endif
" }}}1

" Avoiding side effects {{{1
let s:save_cpo = &cpo
set cpo&vim
" }}}1

function! s:SetGlobalOptDefault(opt, val) "{{{1
  if !exists('g:' . a:opt)
    let g:{a:opt} = a:val
  endif
endfunction
" }}}1

" Set Global Default Options {{{1
call s:SetGlobalOptDefault('markify_error_text', 'E▶')
call s:SetGlobalOptDefault('markify_error_texthl', 'Error')
call s:SetGlobalOptDefault('markify_warning_text', 'W▶')
call s:SetGlobalOptDefault('markify_warning_texthl', 'Todo')
call s:SetGlobalOptDefault('markify_info_text', 'I▶')
call s:SetGlobalOptDefault('markify_info_texthl', 'Normal')
call s:SetGlobalOptDefault('markify_autocmd', 1)
" call s:SetGlobalOptDefault('markify_map', '<Leader>mm')
" call s:SetGlobalOptDefault('markify_clear_map', '<Leader>mc')
" call s:SetGlobalOptDefault('markify_toggle_map', '<Leader>M')
call s:SetGlobalOptDefault('markify_balloon', 1)
call s:SetGlobalOptDefault('markify_echo_current_message', 1)
call s:SetGlobalOptDefault('markify_enabled', 1)
" }}}1

augroup Markify " {{{1
  au!
  if g:markify_echo_current_message
    autocmd CursorMoved * call s:EchoCurrentMessage()
  endif
  if g:markify_autocmd
    autocmd QuickFixCmdPost,BufEnter,WinEnter * call s:Markify()
  end
augroup END
" }}}1

" Define Signs {{{1
execute 'sign define MarkifyError text=' . g:markify_error_text .
      \ ' texthl=' . g:markify_error_texthl
execute 'sign define MarkifyWarning text=' . g:markify_warning_text .
      \ ' texthl=' . g:markify_warning_texthl
execute 'sign define MarkifyInfo text=' . g:markify_info_text .
      \ ' texthl=' . g:markify_info_texthl
" }}}1

if g:markify_balloon
  if has('balloon_eval')
    set ballooneval
  endif
  if has('balloon_eval_term')
    set balloonevalterm
  endif
endif

function! MarkifyBalloonExpr() " {{{1
  for item in getqflist()
    if item.bufnr ==# v:beval_bufnr && item.lnum ==# v:beval_lnum
      return item.text
    endif
  endfor
  return ''
endfunction
" }}}1

function! s:PlaceSigns(items) " {{{1
  let placed = {}
  for item in a:items
    if item.bufnr == 0 || item.lnum == 0 | continue | endif
    let id = item.bufnr . item.lnum
    let sign_name = ''
    let kind = 0
    if item.type ==? 'E'
      let sign_name = 'MarkifyError'
      let kind = 1
    elseif item.type ==? 'W'
      let sign_name = 'MarkifyWarning'
      let kind = 2
    else
      let sign_name = 'MarkifyInfo'
    endif
    let placed[id] = 1
    if has_key(s:sign_ids, id)
      if s:sign_ids[id][0] != kind
        execute 'sign unplace ' . id
        call remove(s:sign_ids, id)
      else
        let s:sign_ids[id][1] = item
        continue
      endif
    endif
    let s:sign_ids[id] = [kind, item]

    execute 'sign place ' . id . ' line=' . item.lnum . ' name=' . sign_name .
          \ ' buffer=' .  item.bufnr
  endfor

  for id in keys(s:sign_ids)
    if !has_key(placed, id)
      execute 'sign unplace ' . id
      call remove(s:sign_ids, id)
    endif
  endfor
endfunction
" }}}1

" function! s:EchoMessage(message) - Taken from Syntastic {{{1
function! s:EchoMessage(kind, message)
  let [old_ruler, old_showcmd] = [&ruler, &showcmd]

  let message = substitute(a:message, "\t", repeat(' ', &tabstop), 'g')
  let message = strpart(message, 0, winwidth(0)-1)
  let message = substitute(message, "\n", '', 'g')

  set noruler noshowcmd
  redraw

  if a:kind == 1
    echohl ErrorMsg | echo message | echohl None
  elseif a:kind == 2
    echohl WarningMsg | echo message | echohl None
  else
    echo message
  endif

  let [&ruler, &showcmd] = [old_ruler, old_showcmd]
endfunction
" }}}1

function! s:EchoCurrentMessage() "{{{1
  let id = bufnr('%') . line('.')
  if !has_key(s:sign_ids, id) | return | endif
  let [kind, item] = s:sign_ids[id]
  call s:EchoMessage(kind, item.text)
endfunction
" }}}1

" function! s:Markify() {{{1
let s:sign_ids = {}
function! s:Markify()
  if !g:markify_enabled | return | endif

  let [items, loclist, qflist] = [[], getloclist(0), getqflist()]
  if !empty(loclist)
    let items = loclist
  elseif !empty(qflist)
    let items = qflist
  else
    call s:MarkifyClear()
    return
  endif

  if g:markify_balloon && (has('balloon_eval') || has('balloon_eval_term'))
    if !empty(&l:balloonexpr)
      let b:old_balloonexpr = &l:balloonexpr
    else
      let b:old_balloonexpr = ''
    endif
    setl balloonexpr=MarkifyBalloonExpr()
  endif

  call s:PlaceSigns(items)
endfunction
" }}}1

function! s:MarkifyClear() " {{{1
  if g:markify_balloon && (has('balloon_eval') || has('balloon_eval_term')) && exists('b:old_balloonexpr')
    if &l:balloonexpr ==# 'MarkifyBalloonExpr()'
      let &l:balloonexpr = b:old_balloonexpr
    endif
    unlet b:old_balloonexpr
  endif
  for sign_id in keys(s:sign_ids)
    exec 'sign unplace ' . sign_id
    call remove(s:sign_ids, sign_id)
  endfor
endfunction
" }}}1

function! s:MarkifyToggle() "{{{1
  let g:markify_enabled = !g:markify_enabled
  if g:markify_enabled
    call s:Markify()
  else
    call s:MarkifyClear()
  endif
endfunction
" }}}1

" Commands & Mappings {{{1
command! -nargs=0 Markify call s:Markify()
command! -nargs=0 MarkifyClear call s:MarkifyClear()
command! -nargs=0 MarkifyToggle call s:MarkifyToggle()

" execute "nnoremap <silent> " . g:markify_map . " :Markify<CR>"
" execute "nnoremap <silent> " . g:markify_clear_map . " :MarkifyClear<CR>"
" execute "nnoremap <silent> " . g:markify_toggle_map . " :MarkifyToggle<CR>"
" }}}1

" Avoid side effects {{{1
let &cpo = s:save_cpo
unlet s:save_cpo
" }}}1

" ModeLine {{{
" vim:fdl=0 fdm=marker
