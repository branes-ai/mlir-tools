# mlir-tools
Superbuild structure for MLIR tools

## Getting started

First recursively clone the submodules:

```bash
git clone --recurse-submodules https://github.com/branes-ai/mlir-tools
```

If it's the first time you check-out a repo you need to use --init first:

```bash
git submodule update --init --recursive
```

For git 1.8.2 or above, the option --remote was added to support updating to latest tips of remote branches:

```bash
git submodule update --recursive --remote
```

This has the added benefit of respecting any "non default" branches specified in the .gitmodules or .git/config files (if you happen to have any, default is origin/main).

For git 1.7.3 or above you can use (but the below gotchas around what update does still apply):

```bash
git submodule update --recursive

or:

git pull --recurse-submodules
```

if you want to pull your submodules to latest commits instead of the current commit the repo points to.

See git-submodule(1) for details

## Reset git submodules by deiniting and initing

We can deinitalizing the submodules and reinitializing the submodules again. This will remove all submodules and reclone them again. So it will take more time than method 1. But this can fix many problems which leads to failures of simplying git reset. The commands are as follows.

```bash
# unbinds all submodules
git submodule deinit -f .
# checkout again
git submodule update --init --recursive
```

The --recursive option make git recursively do update --init under submodules in case these submodules also have submodules.
