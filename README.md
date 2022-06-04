# psql.nvim

This plugin let's you run PSQL commands directly from within Neovim. The core querying logic of this plugin is forked from <a
href="https://github.com/mzarnitsa/psql">this</a> repository. The credit is theirs.

<p align="center">
  <img src="https://hjc-public.s3.amazonaws.com/psql.svg">
</p>

## Requirements

- Neovim 0.7+
- psql

## Installation

Install with your favorite plugin manager, like Packer:

```
  use('harrisoncramer/psql')
```

Then, call the setup function, optionally passing in a settings table:

```lua
  psql.setup({})
```

## Features

This package does not create any key bindings out of the box.

The `psql` module exposes three functions. You can query PostgreSQL for the the current line, with the current paragraph, or with the
current visual selection. These are the mappings that I've created for myself.

```lua
  local map_opts = { noremap = true, silent = true, nowait = true }
  vim.keymap.set("n", "<localleader>r", psql.query_paragraph, map_opts)
  vim.keymap.set("n", "<localleader>e", psql.query_current_line, map_opts)
  vim.keymap.set("v", "<localleader>e", psql.query_selection, map_opts)
```

The output of that command will be piped to a read-only buffer.

## Configuration

By default this plugin will attempt to connect to a PSQL database running on
your localhost. To run commands to a different database, call the `:PSQL` command and supply the
module connection name:

```
:PSQL dev
```

This command will look for a file at `~/.config/nvim/lua/psql/dev.lua` and
will source it, hereafter referred to as the `settings` module. Subsequent commands will run against this database.

The default connection module looks like this:

```lua
return {
  connection = {
    database = "postgres",
    host = "localhost",
    port = 5432,
    password = "postgres", -- See "Passwords"
    username = "postgres",
  },
  hash_algorithm = "sha256",
}
```

For instance, to create to a "production" connection with a password of "108nduiDAF":

```shell
$ printf 108nduiDAF | sha256sum
  db9e46ee0771d27852602bc0a441eea0458c00fd6eca29b59a2d68c085fe8823

cat <<EOF >>~/.config/nvim/psql/lua/production.lua
return {
  connection = {
    database = "production",
    host = "https://super.secret.host",
    port = 5432,
    password = "db9e46ee0771d27852602bc0a441eea0458c00fd6eca29b59a2d68c085fe8823",
    username = "harrison",
  },
  hash_algorithm = "sha256",
}
EOF
```

Then source the module inside Neovim.

```
:PSQL production
```

## Passwords

If you do not supply a password in your configuration module `psql.nvim` will
attempt to use "postgres" as the password. To add your own password,
hash the string, and supply the hashed version to `settings.connection.password` and the
hashing algorithm used to `settings.hash_algorithm`. The supported hashing algorithms are:

- sha224
- sha256
- sha384
- sha512
- sha512_224
- sha512_256

When connecting to a database that requires a password, the hashed version of
your input will be compared against the hashed password contained in your
configuration module.
