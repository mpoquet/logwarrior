# logwarrior
**logwarrior** logs when you work on your [Taskwarrior](https://taskwarrior.org/) tasks.

This is done thanks to a [hook](https://taskwarrior.org/docs/hooks.html) called on `task start` and `task stop` commands.

## Installation
First, compile and install logwarrior's hook into your PATH.  
If you use [Nix](https://nixos.org/nix/), run `nix-env -f https://github.com/mpoquet/logwarrior/archive/master.tar.gz -i`.  
Otherwise, make sure a [D compiler](https://dlang.org/download.html),
[Meson](https://mesonbuild.com) and
[Ninja](https://ninja-build.org) are in your PATH then run:

``` bash
meson build # --prefix=/usr
ninja -C build install
```

Second, tell Taskwarrior to call logwarrior's hook when a task is modified.  
This is done by placing an executable file or script into your Taskwarrior hooks directory (default is `~/.task/hooks/`).

``` bash
ln -s $(realpath $(which logwarrior-hook)) ~/.task/hooks/on-modify-logwarrior
```

## Usage
This is transparent.
Just run `task start` and `task stop` as usual — or let any other program
(e.g., [patata](https://github.com/rrmelcer/patata)) do it for you.

Log files are stored in logwarrior's data directory and formatted as
[CSV](https://fr.wikipedia.org/wiki/Comma-separated_values).
logwarrior simply stores task unique ids with their work intervals in a single file.
This way, you can make the best of taskwarrior's data by [joining](https://en.wikipedia.org/wiki/Relational_algebra#Joins_and_join-like_operators) it with logwarrior's.

By default, logwarrior's data directory is `~/.task` but this can be overriden by setting the
`LOGWARRIOR_DIR` environment variable — e.g., ``LOGWARRIOR_DIR=/tmp task 1 start``.
