#! /bin/bash

# KLEE build script. Run from symModel directory.
# ./buildKlee-2.9.sh
# Author: Manav Sethi <manav.sethi@cse.iitkgp.ernet.in>

BASEDIR=$(pwd)
echo $BASEDIR

# Install klee
# rm -rf "${BASEDIR}/klee"
# git clone 'https://github.com/klee/klee.git'
cd "${BASEDIR}/klee"
./configure --with-llvm="$BASEDIR/llvm-2.9" --with-stp="$BASEDIR/stp-r940/install" --with-uclibc="$BASEDIR/klee-uclibc" --enable-posix-runtime
make ENABLE_OPTIMIZED=1

# Run klee tests
# echo "Testing klee.."
# make check
# make unittests
