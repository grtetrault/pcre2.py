# Adapted from the following submission:
# https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/regexredux-python3-1.html

# The Computer Language Benchmarks Game
# http://shootout.alioth.debian.org/

import pcre2
from sys import stdin
from multiprocessing import Pool

GLOBAL = pcre2.SubstituteOption.GLOBAL

def init_pool(arg):
    global data
    data = arg

def num_matches(patn):
    return sum(1 for _ in pcre2.scan(patn, data))

def main():
    data = stdin.buffer.read()
    init_len = len(data)

    data = pcre2.substitute(b">.*\n|\n", b"", data, options=GLOBAL)
    clean_len = len(data)

    pool = Pool(initializer=init_pool, initargs=(data,))
    variants = (
        b"agggtaaa|tttaccct",
        b"[cgt]gggtaaa|tttaccc[acg]",
        b"a[act]ggtaaa|tttacc[agt]t",
        b"ag[act]gtaaa|tttac[agt]ct",
        b"agg[act]taaa|ttta[agt]cct",
        b"aggg[acg]aaa|ttt[cgt]ccct",
        b"agggt[cgt]aa|tt[acg]accct",
        b"agggta[cgt]a|t[acg]taccct",
        b"agggtaa[cgt]|[acg]ttaccct",
    )
    for var, n in zip(variants, pool.imap(num_matches, variants)):
        print(var.decode(), n)

    subst = {
        b"tHa[Nt]"            : b"<4>",
        b"aND|caN|Ha[DS]|WaS" : b"<3>",
        b"a[NSt]|BY"          : b"<2>",
        b"<[^>]*>"            : b"|",
        b"\\|[^|][^|]*\\|"    : b"-",
    }
    for patn, repl in list(subst.items()):
        data = pcre2.substitute(patn, repl, data, options=GLOBAL)

    print()
    print(init_len)
    print(clean_len)
    print(len(data))

if __name__=="__main__":
    main()
    