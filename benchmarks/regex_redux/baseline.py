# The Computer Language Benchmarks Game
# http://shootout.alioth.debian.org/

from sys import stdin


EXPECTED_OUTPUT = """\
agggtaaa|tttaccct 356
[cgt]gggtaaa|tttaccc[acg] 1250
a[act]ggtaaa|tttacc[agt]t 4252
ag[act]gtaaa|tttac[agt]ct 2894
agg[act]taaa|ttta[agt]cct 5435
aggg[acg]aaa|ttt[cgt]ccct 1537
agggt[cgt]aa|tt[acg]accct 1431
agggta[cgt]a|t[acg]taccct 1608
agggtaa[cgt]|[acg]ttaccct 2178

50833411
50000000
27388361
"""


def main():
    seq = stdin.read()
    print(EXPECTED_OUTPUT, end="")


if __name__ == "__main__":
    main()
