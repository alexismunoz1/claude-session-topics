#!/usr/bin/env python3
"""Verify Python dependencies are installed, provide installation instructions if not."""
import sys

def check_yake():
    try:
        import yake
        return True
    except ImportError:
        return False

if check_yake():
    print("✓ All dependencies installed (YAKE)")
    sys.exit(0)

print("✗ YAKE is not installed")
print("\nInstall with:")
print("  pip3 install yake")
print("\nOr with --break-system-packages if needed:")
print("  pip3 install yake --break-system-packages --user")
sys.exit(1)
