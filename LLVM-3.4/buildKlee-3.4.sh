#! /bin/bash

# KLEE build script. Run from symModel directory.
# ./buildKlee-3.4.sh
# Author: Manav Sethi <manav.sethi@cse.iitkgp.ernet.in>

BASEDIR=$(pwd)
echo $BASEDIR

# Install klee
# rm -rf "${BASEDIR}/klee/build" 
# mkdir "${BASEDIR}/klee/build"
cd "${BASEDIR}/klee/build"
../configure --with-stp="${BASEDIR}/stp/build" --with-uclibc="${BASEDIR}/klee-uclibc" --enable-posix-runtime
make DISABLE_ASSERTIONS=0 ENABLE_OPTIMIZED=1 ENABLE_SHARED=0 -j2

# Run klee regression tests
# cd "${BASEDIR}/klee/build/test"
# make lit.site.cfg DISABLE_ASSERTIONS=0 ENABLE_OPTIMIZED=1 ENABLE_SHARED=0
# lit -v .

# Run klee unit tests
# cd "${BASEDIR}/klee/build"
# make CPPFLAGS=-I"${BASEDIR}/gtest-1.7.0/include" LDFLAGS=-L"${BASEDIR}/gtest-1.7.0" DISABLE_ASSERTIONS=0 ENABLE_OPTIMIZED=1 ENABLE_SHARED=0 unittests
