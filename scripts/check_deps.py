#!/usr/bin/env python3
"""Verify Python dependencies are installed, provide installation instructions if not."""
import sys

def check_yake():
    try:
        import yake
        return True
    except ImportError:
        return False

def check_langdetect():
    try:
        import langdetect
        return True
    except ImportError:
        return False

yake_ok = check_yake()
langdetect_ok = check_langdetect()

if yake_ok and langdetect_ok:
    print("✓ All dependencies installed (YAKE, langdetect)")
    sys.exit(0)

if not yake_ok:
    print("✗ YAKE is not installed")
if not langdetect_ok:
    print("✗ langdetect is not installed")

print("\nInstall with:")
print("  pip3 install yake langdetect")
print("\nOr with --break-system-packages if needed:")
print("  pip3 install yake langdetect --break-system-packages --user")

if not yake_ok:
    sys.exit(1)
if not langdetect_ok:
    sys.exit(2)
