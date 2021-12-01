" Insert or delete brackets, parens, quotes in pairs.
" Maintainer:	Rob Pilling <robpilling@gmail.com>
" Version: 1.0.0
" License: MIT

let s:less_than_checked = { 'pair': '>', 'before': '(^|\w)$' }

let s:pairs = {
\  '(': { 'pair': ')', 'after': '^([^)[:alnum:]]|$)' },
\  '[': { 'pair': ']', 'after': '^([^][:alnum:]]|$)' },
\  '{': { 'pair': '}', 'after': '^([^}[:alnum:]]|$)' },
\  '<': s:less_than_checked,
\  "'": { 'pair': "'", 'before': '[^[:alpha:]]$' },
\  '"': '"',
\  '```': '```',
\  '"""': '"""',
\  "'''": "'''",
\  "`": "`"
\}

let s:pairs_per_ft = {
\  'vim': {
\    '"': { 'pair': '"', 'before': '\S' },
\  },
\  'rust': {
\    "'": { 'pair': "'", 'before': '(^|[^&])$' },
\  },
\}

function! PearInsert(key)
	if !s:enabled()
    return a:key
  end

	let pos = col('.') - 1
	let line = getline('.')
	let before = strpart(line, 0, pos)

  " Ignore auto close if prev character is \
  if before[-1:-1] ==# '\'
    return a:key
  end

	let ent = s:getpair(a:key)
	if type(ent) != v:t_number
		return s:insert_open_or_stepover(a:key, ent)
	endif

	return a:key
endfunction

function! PearStepover(key)
	if !s:enabled()
    return a:key
  end

	let pos = col('.') - 1
	let line = getline('.')
	let after = strpart(line, pos, s:ulen(a:key))

	return after ==# a:key ? s:right : a:key
endfunction

function! PearDelete()
  if !s:enabled()
    return "\<BS>"
  end

	if !s:surrounded()
		return "\<BS>"
	endif
	return "\<BS>\<DELETE>"
endfunction

function! PearReturn()
	if !s:enabled()
    return ''
  end

	if !s:surrounded()
		return "\<CR>"
	endif

	return "\<CR>\<C-O>O"
endfunction

function! PearInitFt()
	if exists('b:pear_maps')
		for key in b:pear_maps
			execute "silent! iunmap <buffer> " .. key
		endfor
	endif

	let for_ft = get(s:pairs_per_ft, &filetype, 0)
	if type(for_ft) ==# v:t_number
		return
	endif

	let b:pear_maps = []
	for key in keys(for_ft)
		call s:imap_pair(key, 1)
	endfor
endfunction

" -----------------------------------------

function! s:enabled()
	return !exists('b:pear_enabled') || b:pear_enabled
endfunction

function! s:insert_open_or_stepover(key, ent)
	let ent = a:ent

	if type(ent) ==# v:t_string
		let close = ent
		"echom "map to " .. close
	else
		let close = ent.pair

		let pos = col('.') - 1
		let line = getline('.')
		let before = strpart(line, 0, pos)

		let re_before = get(ent, 'before', '')
		if !empty(re_before) && match(before, '\v' .. re_before) ==# -1
			"echom "didn't match /" .. re_before .. "/ against '" .. before .. "'"
			return a:key
		endif

		let re_after = get(ent, 'after', '')
		if !empty(re_after)
			let after = strpart(line, pos)
			if match(after, '\v' .. re_after) ==# -1
				"echom "didn't match /" .. re_after .. "/ against '" .. after .. "'"
				return a:key
			endif
		endif
	endif

	if a:key ==# close
		" e.g. closing quotes, etc
		let pos = col('.') - 1
		let line = getline('.')
		let after = strpart(line, pos, s:ulen(a:key))

		if after ==# close
			return s:right
		endif
	endif

	return a:key .. close .. s:lefts(close)
endfunction

function! s:closeparen(ent)
	if type(a:ent) ==# v:t_string
		return a:ent
	endif
	return a:ent.pair
endfunction

function! s:surrounded()
	let pos = col('.') - 1
	if pos ==# 0
		return 0
	endif

	let line = getline('.')
	let before = line[pos - 1]
	let ent = s:getpair(before)
	if type(ent) ==# v:t_number
		return 0
	endif

	let after = line[pos]
	let expected = s:closeparen(ent)
	if after !=# expected
		return 0
	endif

	return 1
endfunction

" -----------------------------------------

function! s:getpair(open)
	let for_ft = get(s:pairs_per_ft, &filetype, 0)
	if type(for_ft) !=# v:t_number
		let ent = get(for_ft, a:open, 0)
		if type(ent) !=# v:t_number
			return ent
		endif
	endif

	return get(s:pairs, a:open, 0)
endfunction

" -----------------------------------------

function! s:init()
	for key in keys(s:pairs)
		call s:imap_pair(key, 0)
	endfor

	execute 'inoremap <silent> <BS> <C-R>=PearDelete()<CR>'
	execute 'inoremap <silent> <C-h> <C-R>=PearDelete()<CR>'

	execute 'inoremap <silent> <CR> <C-R>=PearReturn()<CR>'

	let fts = keys(s:pairs_per_ft)
	execute "autocmd FileType " .. join(fts, ",") .. " call PearInitFt()"
endfunction

function! s:imap_pair(key, buffer)
	call s:imap(a:key, 'PearInsert', a:buffer)

	let ent = s:getpair(a:key)
	let close = s:closeparen(ent)

	if a:key !=# close
		call s:imap(close, 'PearStepover', a:buffer)
	endif
endfunction

function! s:imap(key, func, buffer)
  " | is special key which separate map command from text
  let key = a:key
  if key ==# '|'
    let key = '<BAR>'
  end
  let escaped_key = substitute(key, "'", "''", 'g')

	let args = a:buffer ? '<buffer> ' : ''

  " use expr will cause search() to not work
  execute 'inoremap <silent> ' .. args .. key .. " <C-R>=" .. a:func .. "('" .. escaped_key .. "')<CR>"

	if a:buffer
		call add(b:pear_maps, escaped_key)
	endif
endfunction

" -----------------------------------------

" 7.4.849 support <C-G>U to avoid breaking '.'
" Issue talk: https://github.com/jiangmiao/auto-pairs/issues/3
" Vim note: https://github.com/vim/vim/releases/tag/v7.4.849
if v:version > 704 || v:version == 704 && has("patch849")
  let s:go = "\<C-G>U"
else
  let s:go = ""
endif

let s:left = s:go .. "\<LEFT>"
let s:right = s:go .. "\<RIGHT>"

" unicode len
function! s:ulen(s)
  return len(split(a:s, '\zs'))
endfunction

function! s:lefts(s)
  return repeat(s:left, s:ulen(a:s))
endfunction

" -----------------------------------------

call s:init()
