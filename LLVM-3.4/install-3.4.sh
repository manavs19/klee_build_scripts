#! /bin/bash

# KLEE install script.
# ./install-3.4.sh
# Sets up llvm 3.4, upstream STP, 0_9_29 klee-uclibc, gtest 1.7.0, and KLEE.
# Based on http://klee.github.io/klee/GetStarted.html , http://klee.github.io/klee/Experimental.html 
# Tested on 64-bit Ubuntu 14.04.
# Author: Manav Sethi <manav.sethi@cse.iitkgp.ernet.in>

BASEDIR=$(pwd)
echo "Installing KLEE and dependencies to ${BASEDIR}"

# Add llvm repository
if ! grep 'deb http://llvm.org/apt/trusty/ llvm-toolchain-trusty-3.4 main' "/etc/apt/sources.list"
then
        echo -e 'deb http://llvm.org/apt/trusty/ llvm-toolchain-trusty-3.4 main\ndeb-src http://llvm.org/apt/trusty/ llvm-toolchain-trusty-3.4 main' | sudo tee -a "/etc/apt/sources.list"
fi
wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key|sudo apt-key add - 

# Install required packages (incl. llvm)
sudo apt-get update
sudo apt-get install -y build-essential curl python-minimal python-pip git bison flex bc libcap-dev git cmake libboost-all-dev valgrind libncurses5-dev clang-3.4 llvm-3.4 llvm-3.4-dev llvm-3.4-tools unzip

sudo ln -sf "/usr/bin/llvm-config-3.4" "/usr/bin/llvm-config"

# Persist environment variables
sudo sh -c 'echo "export C_INCLUDE_PATH=/usr/include/x86_64-linux-gnu" > /etc/profile.d/kleevars.sh'
sudo sh -c 'echo "export CPLUS_INCLUDE_PATH=/usr/include/x86_64-linux-gnu" >> /etc/profile.d/kleevars.sh'
. "/etc/profile.d/kleevars.sh"

# Install stp
rm -rf "${BASEDIR}/minisat"
git clone https://github.com/stp/minisat.git
cd minisat
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr/ ../
sudo make install
cd ../../

rm -rf "${BASEDIR}/stp"
git clone 'https://github.com/stp/stp.git'
mkdir "${BASEDIR}/stp/build"
cd "${BASEDIR}/stp/build"
# Upstream STP builds shared libraries by default, which causes problems for KLEE, so we disable them 
# (see: https://www.mail-archive.com/klee-dev@imperial.ac.uk/msg01704.html )
# The Python interface requires shared libraries, so we have to disable that, too. Unfortunately, this 
# disables testing, but we normally don't want to run STP tests anyway.
cmake -DBUILD_SHARED_LIBS:BOOL=OFF -DENABLE_PYTHON_INTERFACE:BOOL=OFF ..
make
sudo make install

# Increasing stack and number of open files limit. 
#ulimit -s unlimited
if ! grep '*\t\thard\tstack\t\tunlimited' "/etc/security/limits.conf"
then
        echo -e '*\t\thard\tstack\t\tunlimited\n*\t\tsoft\tstack\t\tunlimited\n*\t\thard\tnofile\t\t999999\n*\t\tsoft\tnofile\t\t999999' | sudo tee -a "/etc/security/limits.conf"
fi

# Install klee-uclibc
cd "$BASEDIR"
rm -rf "${BASEDIR}/klee-uclibc"
git clone https://github.com/klee/klee-uclibc.git 
cd "${BASEDIR}/klee-uclibc"
./configure --make-llvm-lib
make -j2

# Install gtest
cd "$BASEDIR"
rm -rf "${BASEDIR}/gtest-1.7.0"
curl -OL https://googletest.googlecode.com/files/gtest-1.7.0.zip
unzip "gtest-1.7.0.zip"
cd "${BASEDIR}/gtest-1.7.0"
cmake .
make

# Install klee
cd "$BASEDIR"
rm -rf "${BASEDIR}/klee"
git clone 'https://github.com/klee/klee.git'
mkdir "${BASEDIR}/klee/build"
cd "${BASEDIR}/klee/build"
../configure --with-stp="${BASEDIR}/stp/build" --with-uclibc="${BASEDIR}/klee-uclibc" --enable-posix-runtime
make DISABLE_ASSERTIONS=0 ENABLE_OPTIMIZED=1 ENABLE_SHARED=0 -j2
sudo sh -c 'echo "export PATH=\$PATH:'"${BASEDIR}/klee/build/Release+Asserts/bin"'" >> /etc/profile.d/kleevars.sh'
. "/etc/profile.d/kleevars.sh"

# Install lit (not installed with the newer llvm versions)
cd "${BASEDIR}/klee/build/test"
sudo pip install lit

# Run klee regression tests
make lit.site.cfg DISABLE_ASSERTIONS=0 ENABLE_OPTIMIZED=1 ENABLE_SHARED=0
lit -v .

# Get llvm unit tests makefile (not included in default installation)
cd "${BASEDIR}/klee/build"
sudo mkdir -p "/usr/lib/llvm-3.4/build/unittests/"
sudo curl -L http://llvm.org/svn/llvm-project/llvm/branches/release_34/unittests/Makefile.unittest -o /usr/lib/llvm-3.4/build/unittests/Makefile.unittest

# Run klee unit tests
make CPPFLAGS=-I"${BASEDIR}/gtest-1.7.0/include" LDFLAGS=-L"${BASEDIR}/gtest-1.7.0" DISABLE_ASSERTIONS=0 ENABLE_OPTIMIZED=1 ENABLE_SHARED=0 unittests
