return {
  {
    "omacom/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg = "#161414",
        dark_bg = "#100E0E",
        darker_bg = "#0B0909",
        lighter_bg = "#262120",

        fg = "#E5DCCC",
        dark_fg = "#A2978D",
        light_fg = "#CBBFAE",
        bright_fg = "#F3EBDD",
        muted = "#A2978D",

        red = "#D1847C",
        yellow = "#D8B77F",
        orange = "#CD986D",
        green = "#ACB597",
        cyan = "#8EB6B1",
        blue = "#9DAEBF",
        magenta = "#BC8F9D",
        brown = "#AE8C71",

        bright_red = "#E4A099",
        bright_yellow = "#EBCD9C",
        bright_green = "#C6CDB4",
        bright_cyan = "#B1D0C9",
        bright_blue = "#BECBDC",
        bright_magenta = "#D4ACBA",

        accent = "#D0A267",
        cursor = "#F3EBDD",
        foreground = "#E5DCCC",
        background = "#161414",
        selection = "#514032",
        selection_foreground = "#E5DCCC",
        selection_background = "#514032",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
