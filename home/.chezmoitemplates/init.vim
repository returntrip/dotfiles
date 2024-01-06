"" Plugins system start
call plug#begin()
Plug 'tpope/vim-sensible'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}
Plug 'godlygeek/tabular'
Plug 'preservim/vim-markdown'
Plug 'hashivim/vim-terraform'
Plug 'dense-analysis/ale'
Plug 'alker0/chezmoi.vim'
call plug#end()
"" `vim-markdown` settings
let g:mkdp_auto_close = 1 " Markdown preview: do not close the preview tab when switching to other buffers
let g:vim_markdown_folding_disabled = 1 " disable header folding
let g:vim_markdown_conceal = 1 " do not use conceal feature, the implementation is not so good
let g:tex_conceal = "" " disable math tex conceal feature
let g:vim_markdown_math = 1
let g:vim_markdown_frontmatter = 1  " font matter for YAML format
let g:vim_markdown_toml_frontmatter = 1  " font matter for TOML format
let g:vim_markdown_json_frontmatter = 1  " font matter for JSON format
"" General Improvements
set mouse=a "activates mouse for all modes
filetype plugin indent on " indentation base on file type
set tabstop=4 " sets space number for tab
set softtabstop=4 " set space like tabstops for <BS> to function correctly
set shiftwidth=4 " when indenting with '>', use 4 spaces width 
set expandtab " On pressing tab, insert 4 spaces
set undofile " activate undo also if vim was closed
set errorbells
set visualbell
set clipboard+=unnamedplus
set title
"" Colors
set termguicolors "truecolor
colorscheme  torte
" for yaml/yml files set 2 spaces
autocmd Filetype yaml setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
" terraform plugin settings
let g:hcl_align=1
let g:hcl_fold_sections=1
let g:terraform_align=1
let g:terraform_fmt_on_save=1
let g:terraform_fold_sections=1
autocmd Filetype terraform setlocal foldlevel=1
