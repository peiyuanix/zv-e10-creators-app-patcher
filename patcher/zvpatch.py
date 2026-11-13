#!/usr/bin/env python3
"""Compatibility entry point for the Creators' App 3.5.0 patcher."""
import runpy
from pathlib import Path

if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).resolve().parent / "3.5" / "zvpatch.py"), run_name="__main__")
