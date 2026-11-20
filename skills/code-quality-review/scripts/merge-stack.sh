#!/bin/sh
# Merges pull request branches, in order, into a throwaway worktree, so the end state of a stack can be read and
# searched as one tree.
#
# Usage: merge-stack.sh <repo> <worktree-dir> <base-ref> <ref>...
#   merge-stack.sh ~/code/my-repo "$SCRATCH/merged" origin/main origin/feat/a origin/feat/b
#
# A conflict keeps both sides (git merge-file --union) and is listed, so a conflicted source file may not compile.
# The worktree is detached and for reading only: never commit from it or push it. Remove it afterwards with
#   git -C <repo> worktree remove --force <worktree-dir> && git -C <repo> worktree prune
set -eu

if [ $# -lt 4 ]; then
  echo "usage: $0 <repo> <worktree-dir> <base-ref> <ref>..." >&2
  exit 2
fi

repo=$1
dir=$2
base=$3
shift 3

if [ -e "$dir" ]; then
  echo "$dir already exists; pick a new directory" >&2
  exit 1
fi

in_dir() { git -C "$dir" -c user.name=code-quality-review -c user.email=code-quality-review@localhost "$@"; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$dir" "$base" >/dev/null 2>&1
echo "base $base"

for ref in "$@"; do
  if in_dir merge --no-edit -q "$ref" >/dev/null 2>&1; then
    echo "merged $ref"
    continue
  fi

  echo "merged $ref, kept both sides of the conflicts in:"
  in_dir diff --name-only --diff-filter=U >"$tmp/conflicts"
  while read -r file; do
    # A side that deleted the file has no stage; it counts as empty.
    in_dir show ":1:$file" >"$tmp/base" 2>/dev/null || : >"$tmp/base"
    in_dir show ":2:$file" >"$tmp/ours" 2>/dev/null || : >"$tmp/ours"
    in_dir show ":3:$file" >"$tmp/theirs" 2>/dev/null || : >"$tmp/theirs"
    git merge-file --union -p "$tmp/ours" "$tmp/base" "$tmp/theirs" >"$dir/$file" || true
    in_dir add -- "$file"
    echo "  $file"
  done <"$tmp/conflicts"
  in_dir commit -q --no-edit
done

echo "end state in $dir"
