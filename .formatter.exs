[
  import_deps: [:ecto, :phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  subdirectories: ["priv/*/migrations"],
  line_length: 120,
  # keep <%= %> in .heex templates rather than rewriting them all to {}
  migrate_eex_to_curly_interpolation: false
]
