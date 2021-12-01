Fork
====

Fork of jiangmiao/auto-pairs

Vim Pear
========
Insert or delete brackets, parens, quotes in pair.

Fork Changes
------------

Requirements:
- Insert matching bracket or quote
  - Don't insert bracket if: `|hello`, since we're probably fixing up code
- Walk-over paren on close-quote / close-bracket
- Auto-delete on backspace over opening-quote/bracket
- Handling of "I'm"
- Redo / `.`
- Handle `<>`
- Handle `\(`
- Small file size

Changes:
- Remove `<M-*>` shortcuts
- Smart angle brackets
- No space inside brackets on `<Space>` (`g:AutoPairsMapSpace = 0`)
- Add smart open detection (second requirement bullet point / [jiangmiao/auto-pairs/issues/343])

[jiangmiao/auto-pairs/issues/343]: https://github.com/jiangmiao/auto-pairs/issues/343

License
-------

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
