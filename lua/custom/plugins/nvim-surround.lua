return {
  "tpope/vim-surround",
  event = "VeryLazy",
  -- No config needed; tpope/vim-surround works out of the box
  -- Keybindings Reference:
  -- Normal Mode:
  --   ys{motion}{char} - Add surrounding (e.g., ysiw" for quotes around word)
  --   yss{char}        - Surround entire line
  --   yS{motion}{char} - Surround with newlines
  --   ySS{char}        - Surround entire line with newlines
  --   ds{char}         - Delete surrounding characters
  --   cs{target}{char} - Change surrounding from target to char
  --   cS{target}{char} - Change surrounding with newlines
  -- Visual Mode:
  --   S{char}          - Surround selected text
  --   gS{char}         - Surround selected text with newlines
  -- Common chars: (), [], {}, <>, ' , ", `, t (tags), f (function)
  -- Examples:
  --   ysiw)  - (word)
  --   ysiw(  - ( word )
  --   ds"    - Delete quotes
  --   cs'"   - Change single to double quotes
  --   ysiw<p> - Surround word with <p> tags
}

