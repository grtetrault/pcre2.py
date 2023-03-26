# -*- coding:utf-8 -*-

import pcre2
import pathlib
import subprocess


PROJ_CWD = pathlib.Path(__file__).parents[1]

# Note that commands are relative to the project directory.
PYTHON = PROJ_CWD.joinpath(".venv/bin/python3")
INPUT_DATA = PROJ_CWD.joinpath("benchmarks/regex_redux/input.txt")
SCRIPTS = [
    # PROJ_CWD.joinpath("benchmarks/regex_redux/baseline.py"),
    # PROJ_CWD.joinpath("benchmarks/regex_redux/vanilla.py"),
    PROJ_CWD.joinpath("benchmarks/regex_redux/hand_optimized.py"),
    PROJ_CWD.joinpath("benchmarks/regex_redux/pcre2_module.py"),
]
NUM_RUNS = 1

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
""".encode()

if __name__ == "__main__":
    print("Running RegexRedux Benchmarks")

    print("Using CWD:", PROJ_CWD)
    with open(INPUT_DATA, "br") as f:
        data = f.read()

    results = (
        "+-------------------+----------+----------+----------+----------+----------+\n"
        "| script            | ncalls   | tottime  | real     | user     | sys      |\n"
        "+-------------------+----------+----------+----------+----------+----------+\n"
    )
    elem_add = lambda tup1, tup2: tuple(map(lambda i, j: i + j, tup1, tup2))
    for script in SCRIPTS:
        cmd = ["time", PYTHON, script]
        print("Executing CMD:", list(map(lambda c: str(c), cmd)))
        print("Total Iterations:", NUM_RUNS, "| ", end="", flush=True)

        total_stats = 0, 0, 0
        for _ in range(NUM_RUNS):
            print(".", end="", flush=True)
            out = subprocess.run(cmd, input=data, capture_output=True, cwd=PROJ_CWD)
            
            try:
                assert out.stdout == EXPECTED_OUTPUT
            except AssertionError as e:
                print(f"\nUnexpected output on script {script}")
                print("==========\nReceived:")
                print(out.stdout.decode())
                print("==========\nExpected:")
                print(EXPECTED_OUTPUT.decode())
                raise e

            time_match = pcre2.match(
                r"({0})\sreal\s*({0})\suser\s*({0})\ssys".format(r"[0-9]+\.[0-9]+").encode(),
                out.stderr
            )
            cur_stats = float(time_match[1]), float(time_match[2]), float(time_match[3])
            total_stats = elem_add(total_stats, cur_stats)
        print(" DONE", flush=True)

        avg_stats = tuple(map(lambda i: i / NUM_RUNS, total_stats))
        results += (
            f"| {script.name:<18}"
            f"| {NUM_RUNS:8} | {total_stats[0]:8.3f} "
            f"| {avg_stats[0]:8.3f} | {avg_stats[1]:8.3f} | {avg_stats[2]:8.3f} |\n"
        )
    results += (
        "+-------------------+----------+----------+----------+----------+----------+\n"
    )
    print(results)
