" Insert or delete brackets, parens, quotes in pairs.
" Maintainer:	Rob Pilling <robpilling@gmail.com>
" Version: 1.0.0
" License: MIT

let s:after_paren = '^([^a-zA-Z0-9$_({[]|$)'
let s:non_quotable = '^($|\s|[])}])' " allow quotes before specific chars

let s:less_than_checked = {
\  'pair': '>',
\  'before': '(^|[^ \t<])$',
\  'after': s:after_paren,
\ }

let s:pairs = {
\  '(': { 'pair': ')', 'after': s:after_paren },
\  '[': { 'pair': ']', 'after': s:after_paren },
\  '{': { 'pair': '}', 'after': s:after_paren, 'close-line': 1 },
\  '<': s:less_than_checked,
\  "'": { 'pair': "'", 'after': s:non_quotable, 'before': '(^|[^[:alnum:]])$', 'only-if-even': 1 },
\  '"': { 'pair': '"', 'after': s:non_quotable, 'only-if-even': 1 },
\  "`": { 'pair': "`", 'after': s:non_quotable, 'only-if-even': 1 },
\  '```': { 'pair': '```', 'after': s:non_quotable }
\}

let s:rust_lifetime_before_not = [
\  '[&+] *$',
\  '<where +$',
\  "^[^']*'[^']*: *$",
\  '[A-Z]\k* *: *$',
\  "\\k\\<(('[a-z]+|\\k+), *)*$",
\  "^\s*$",
\]
" above correspond to:
"   &'a i32
"   where 'a: ...
"   'a: 'b
"   T: 'a
"   T<'a>, T<'b, 'a>, T<X, 'a, Y, 'b>
"   new/empty line, label

let s:pairs_per_ft = {
\  'vim': {
\    '"': { 'pair': '"', 'after': '^(\s|$)', 'before': '\S' },
\  },
\  'rust': {
\    "'": { 'pair': "'", 'before': s:pairs["'"].before, 'before-not': join(s:rust_lifetime_before_not, '|') },
\    "|": { 'pair': "|", 'before': '[,(=] *$', 'after': '^($|\))' }
\  },
\  'python': {
\    '"""': { 'pair': '"""', 'after': s:non_quotable },
\    "'''": { 'pair': "'''", 'after': s:non_quotable },
\  },
\}

function! PearInsert(key)
	if s:skip() || pumvisible()
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
	" don't check pumvisible() here - permit closing a pair during completion
	if s:skip()
		return a:key
	end

	let pos = col('.') - 1
	let line = getline('.')
	let after = strpart(line, pos, s:ulen(a:key))

	return after ==# a:key ? s:right : a:key
endfunction

function! PearDelete()
	if s:skip() || pumvisible()
		return "\<BS>"
	end

	if !s:surrounded_tight(0)
		return "\<BS>"
	endif
	return "\<BS>\<DELETE>"
endfunction

function! PearReturn()
	if s:skip()
		return "\<CR>"
	end

	let ent = s:surrounded_tight(1)
	if ent is 0
		return "\<CR>"
	endif

	if !&cindent
		" we'll indent nicely already
		return "\<CR>\<C-O>O"
	endif

	" <Enter><Esc>O works, but leaves indent skewed, so:
	return "\<CR>\<Esc>k^jd^O"
endfunction

function! PearInitFt()
	if exists('b:pear_maps')
		for key in b:pear_maps
			execute "silent! iunmap <buffer> " . key
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

function! s:skip()
	return mode() ==# 'R' || (exists('b:pear_enabled') && !b:pear_enabled)
endfunction

function! s:insert_open_or_stepover(key, ent)
	let ent = a:ent

	let pos = col('.') - 1
	let line = getline('.')
	let before = strpart(line, 0, pos)

	" if the open and close are the same, check stepover before
	" trying to insert the close (or not and keeping the open quote)
	let close = ent.pair
	if a:key ==# close
		" e.g. closing quotes, etc
		let after = strpart(line, pos, s:ulen(a:key))

		if after ==# close
			return s:right
		endif
	endif

	let re_before = get(ent, 'before', '')
	if !empty(re_before) && match(before, '\v' . re_before) ==# -1
		"echom "didn't match /" . re_before . "/ against '" . before . "'"
		return a:key
	endif

	let re_before_not = get(ent, 'before-not', '')
	if !empty(re_before_not) && match(before, '\v' . re_before_not) !=# -1
		"echom "matched /" . re_before_not . "/ against '" . before . "'"
		return a:key
	endif

	let re_after = get(ent, 'after', '')
	if !empty(re_after)
		let after = strpart(line, pos)
		if match(after, '\v' . re_after) ==# -1
			"echom "didn't match /" . re_after . "/ against '" . after . "'"
			return a:key
		endif
	endif

	if get(ent, 'only-if-even', 0)
		" don't insert a corresponding close if there's an odd number before
		let n = count(before, a:key)
		if n % 2 != 0
			"echom "odd number (" . n . ") of '" . a:key
			return a:key
		endif
	endif

	if get(ent, 'close-line', 0) && s:maybe_insert_matching_close(close)
		return a:key
	endif

	return a:key . close . s:repeated(s:left, close)
endfunction

function! s:maybe_insert_matching_close(close)
	" don't do this for pairs which are likely to want to remain on a single line
	let [_buf, l, col, off, _curswant] = getcurpos()
	let relevant = getline(l)[:col - 1]

	" if we're after a close paren, it's like that:
	" if() |
	"      ^ we're here or there's no close paren
	"      in which case, don't close-line.
	"      (except we allow `loop` as a special case)
	if stridx(relevant, ")") < 0 && relevant !~# '\<loop\>'
		return 0
	endif

	" are we inside a pair? e.g. f({}) or "x={0}"
	if s:surrounded_loose_ish()
		return 0
	endif

	let curindent = indent(l)

	"echom "looking for where to add " . a:close . " after line " . l

	let l_start = l
	let l_end = line('$')

	let l += 1
	let nextindent = indent(l)
	" second part below: nothing to wrap
	if nextindent < curindent || (curindent == 0 && empty(getline(l_start+1)))
		"echom "no indent after line" l . ", cancelled"
		return 0
	endif

	let find_empty = nextindent == curindent

	let found = 0
	while l <= l_end
		let is_empty = empty(getline(l))

		if !is_empty
			let i = indent(l)
			if i < (find_empty ? curindent : nextindent)
				let found = 1
				break
			endif
		elseif find_empty
			let found = 1
			break
		endif

		let l += 1
	endwhile

	if !found
		"echom "no line found"
		return 0
	endif

	"echom "line found: " . l
	let indent = substitute(getline(l_start), '\S.*', '', '')

	if find_empty && is_empty
		let candidate = getline(max([l-1, l_start+1]))
	else
		let candidate = getline(l)
	endif

	if candidate =~# '^' . indent . a:close
		"echom "already has closing pair, skipping insertion only"
	else
		" wind back to the last non-empty line
		if !find_empty || !is_empty
			let l -= 1
		endif
		while l > 0 && empty(getline(l))
			let l -= 1
		endwhile

		call append(l, indent . a:close)
	endif

	return 1
endfunction

function! s:surrounded_loose_ish()
	let [_buf, l, col, off, curswant] = getcurpos()
	let line = getline(l)

	" searchpairpos() - we must move the cursor back before calling this
	call cursor(l, col - 1)
	let stopline = l+1
	try
		for open in keys(s:pairs)
			let close = s:pairs[open]['pair']

			if open ==# close
				" searchpair doesn't work here
				if stridx(line, open) < col - 1 && stridx(line, open, col-1) >= 0
					" we're between
					return 1
				endif
			else
				let [fline, fcol] = searchpairpos(open, "", close, "zn", "", stopline)
				if fline > 0 && fcol > 0
					" found the pair on this line (z), cursor hasn't moved (n)
					" could be:
					" if | ()
					"    ^ cursor
					" but we ignore this case (hence _ish) and act as if we found:
					" if ( | )
					"
					" so we're in a pair already, don't make a new line:
					return 1
				endif
			endif
		endfor
	finally
		call cursor([l, col, off, curswant])
	endtry
	return 0
endfunction

function! s:surrounded_tight(ret_ent)
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
	let expected = ent.pair
	if after !=# expected
		return 0
	endif

	return a:ret_ent ? ent : 1
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
	execute "autocmd FileType " . join(fts, ",") . " call PearInitFt()"
endfunction

function! s:imap_pair(key, buffer)
	call s:imap(a:key, 'PearInsert', a:buffer)

	let ent = s:getpair(a:key)
	let close = ent.pair

	if a:key !=# close
		call s:imap(close, 'PearStepover', a:buffer)
	endif
endfunction

function! s:imap(key, func, buffer)
	" | is special key which separates map command from text
	let key = a:key
	if key ==# '|'
		let key = '<BAR>'
	end
	let escaped_key = substitute(key, "'", "''", 'g')

	let args = a:buffer ? '<buffer> ' : ''

	" use expr will cause search() to not work
	execute 'inoremap <silent> ' . args . key . " <C-R>=" . a:func . "('" . escaped_key . "')<CR>"

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

let s:left = s:go . "\<LEFT>"
let s:right = s:go . "\<RIGHT>"

" unicode len
function! s:ulen(s)
	return len(split(a:s, '\zs'))
endfunction

function! s:repeated(s, by)
	return repeat(a:s, s:ulen(a:by))
endfunction

" -----------------------------------------

call s:init()
