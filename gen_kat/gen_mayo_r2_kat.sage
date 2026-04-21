#!/usr/bin/env sage -python
import argparse
import re
from pathlib import Path
import random
from sagelib.mayo import setupMayo

PARAM_SETS = ['mayo_1', 'mayo_2', 'mayo_3', 'mayo_5']


def resolve_message_lengths(limit, min_len, max_len):
    if limit <= 0:
        return []
    if min_len < 0:
        raise ValueError('min_len must be non-negative')
    if max_len < min_len:
        raise ValueError('max_len must be greater than or equal to min_len')

    return [random.randint(min_len, max_len) for _ in range(limit)]


def generate_random_cases(param_set, limit, min_len, max_len):
    mayo = setupMayo(param_set)
    cases = []

    for msg_len in resolve_message_lengths(limit, min_len, max_len):
        msg = mayo.random_bytes(msg_len)
        csk, cpk = mayo.compact_key_gen()
        esk, _ = mayo.expand_sk(csk)
        sig = mayo.sign(msg, esk)[:mayo.sig_bytes]

        cases.append({
            'LENGTH': str(msg_len),
            'MSG': msg.hex().upper(),
            'CSK': csk.hex().upper(),
            'CPK': cpk.hex().upper(),
            'SIGNATURE': sig.hex().upper(),
        })

    return cases


def write_cases(dst, cases):
    dst.parent.mkdir(parents=True, exist_ok=True)
    with dst.open('w') as f:
        for i, c in enumerate(cases, 1):
            f.write(f"# Case {i}\n")
            f.write(f"LENGTH={c['LENGTH']}\n")
            f.write(f"MSG={c['MSG']}\n")
            f.write(f"CSK={c['CSK']}\n")
            f.write(f"CPK={c['CPK']}\n")
            f.write(f"SIGNATURE={c['SIGNATURE']}\n")
            if i != len(cases):
                f.write("\n")


def resolve_set_number(param_set):
    mapping = {
        'mayo_1': 1,
        'mayo_2': 2,
        'mayo_3': 3,
        'mayo_5': 5,
    }
    return mapping[param_set]


def resolve_path(param_set):
    return Path(f"KAT_R2_S{resolve_set_number(param_set)}.kat")


def main():
    ap = argparse.ArgumentParser(description='Generate random mayo TB KAT format')
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--param', choices=PARAM_SETS)
    ap.add_argument('--min-msg-len', type=int, default=8)
    ap.add_argument('--max-msg-len', type=int, default=65535)
    args = ap.parse_args()

    if args.limit <= 0:
        raise SystemExit('Provide --limit > 0 to generate random cases.')

    param_sets = [args.param] if args.param else PARAM_SETS
    for param_set in param_sets:
        dst = resolve_path(param_set)
        cases = generate_random_cases(param_set, args.limit, args.min_msg_len, args.max_msg_len)
        write_cases(dst, cases)
        print(f"Wrote {len(cases)} case(s) to {dst}")


if __name__ == '__main__':
    main()
