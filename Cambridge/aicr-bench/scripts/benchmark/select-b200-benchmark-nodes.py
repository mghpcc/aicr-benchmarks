#!/usr/bin/env python3
import os
import sys
from pathlib import Path


def main():
    target = Path(__file__).with_name("select-benchmark-nodes.py")
    os.execv(sys.executable, [sys.executable, str(target), *sys.argv[1:]])


if __name__ == "__main__":
    main()
