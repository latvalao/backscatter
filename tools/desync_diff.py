#!/usr/bin/env python3
"""Compare two desync dumps (user://desync/*.txt from each peer) and print the
first differing entities/components.  Usage: tools/desync_diff.py a.txt b.txt"""
import sys

def load(p):
    with open(p) as f:
        return [l.rstrip("\n") for l in f]

a, b = load(sys.argv[1]), load(sys.argv[2])
print(a[0]); print(b[0])
sa, sb = set(a[1:]), set(b[1:])
only_a = [l for l in a[1:] if l not in sb]
only_b = [l for l in b[1:] if l not in sa]
for l in only_a[:40]:
    print("- " + l)
for l in only_b[:40]:
    print("+ " + l)
print(f"{len(only_a)} lines only in A, {len(only_b)} only in B")
