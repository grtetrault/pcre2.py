# Adapted from the following submission:
# https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/regexredux-python3-1.html
#
# The Computer Language Benchmarks Game
# http://shootout.alioth.debian.org/

import sys
import pcre2
import itertools
import collections
import multiprocessing as mp

GLOBAL = pcre2.SubstituteOption.GLOBAL


def init_pool(_data):
    # Pool initializer
    global data
    data = _data


def n_matches(patn):
    # Pool worker
    # Get number of non-overlapping matches in data global to pool.
    n = sum(1 for _ in pcre2.scan(patn, data))
    return patn.decode(), n


def seq_subs(data, subs, result):
    # Process worker
    # Apply sequential substitions to given data and store in multiprocess
    # manager value.
    for patn, repl in subs:
        data = pcre2.substitute(patn, repl, data, options=GLOBAL)
    result.value = data


def main():
    data = sys.stdin.buffer.read()
    init_len = len(data)

    data = pcre2.substitute(b">.*\n|\n", b"", data, options=GLOBAL)
    clean_len = len(data)

    patns = (
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
    subs = [
        (b"tHa[Nt]", b"<4>"),
        (b"aND|caN|Ha[DS]|WaS", b"<3>"),
        (b"a[NSt]|BY", b"<2>"),
        (b"<[^>]*>", b"|"),
        (b"\\|[^|][^|]*\\|", b"-"),
    ]

    # Kick off sequential substitutions in the background.
    result = mp.Manager().Value(str, "")
    process = mp.Process(target=seq_subs, args=(data, subs, result))
    process.start()
    
    # Run match counts in parallel with substitutions.
    pool = mp.Pool(initializer=init_pool, initargs=(data,))
    for patn, n in pool.imap(n_matches, patns, chunksize=3):
        print(patn, n)
    pool.close()

    # Get results from substitution process.
    process.join()
    data = result.value

    print()
    print(init_len)
    print(clean_len)
    print(len(data))


if __name__=="__main__":
    main()
    