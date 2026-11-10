#!/bin/sh
# Compiles the maqam sketch for the Mac with memory checking on and runs the tests.
set -e
cd "$(dirname "$0")/.."
mkdir -p build/test
clang++ -std=c++14 -g -O1 -w -fsanitize=address,undefined -fno-sanitize-recover=address \
  -x c++ -include tests/shim/shim.h -Itests/shim \
  -DSKETCH='"../kastl-arb.ino"' tests/test_maqam.cpp -o build/test/test_maqam
./build/test/test_maqam
