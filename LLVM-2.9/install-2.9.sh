#! /bin/bash

# KLEE install script.
# ./install-2.9.sh
# Sets up llvm-gcc 4.2, llvm 2.9, upstream STP, 0_9_29 klee-uclibc, and KLEE.#
# Based on http://klee.github.io/getting-started/# 
# Tested on 64-bit Ubuntu 14.04.2#
# Author: Manav Sethi <manav.sethi@cse.iitkgp.ernet.in>

BASEDIR=$(pwd)
echo "Installing KLEE and dependencies to ${BASEDIR}"

# Install required packages
echo "Updating and installing required packages"
sudo apt-get update
sudo apt-get install -y g++ curl dejagnu subversion bison flex bc libcap-dev ncurses-dev build-essential python-minimal git cmake libboost-all-dev valgrind libm4ri-dev libmysqlclient-dev libsqlite3-dev libtbb-dev libncurses5-dev

# Persist environment variables
sudo sh -c 'echo "export C_INCLUDE_PATH=/usr/include/x86_64-linux-gnu" > /etc/profile.d/kleevars.sh'
sudo sh -c 'echo "export CPLUS_INCLUDE_PATH=/usr/include/x86_64-linux-gnu" >> /etc/profile.d/kleevars.sh'
. "/etc/profile.d/kleevars.sh"

# Install llvm-gcc
echo "Installing llvm-gcc.."
rm -rf "${BASEDIR}/llvm-gcc4.2-2.9-x86_64-linux" "${BASEDIR}/llvm-gcc4.2-2.9-x86_64-linux.tar.bz2"
curl -4OL 'http://llvm.org/releases/2.9/llvm-gcc4.2-2.9-x86_64-linux.tar.bz2'
tar xvf "llvm-gcc4.2-2.9-x86_64-linux.tar.bz2"
sudo sh -c 'echo export PATH=\$PATH:'${BASEDIR}'/llvm-gcc4.2-2.9-x86_64-linux/bin >> /etc/profile.d/kleevars.sh'
. "/etc/profile.d/kleevars.sh"

# Install llvm
echo "Installing llvm.."
rm -rf "${BASEDIR}/llvm-2.9" "${BASEDIR}/llvm-2.9.tgz"
curl -4OL 'http://llvm.org/releases/2.9/llvm-2.9.tgz'
tar zxvf llvm-2.9.tgz
# See: https://www.mail-archive.com/klee-dev@imperial.ac.uk/msg01302.html
patch "llvm-2.9/lib/ExecutionEngine/JIT/Intercept.cpp" "patches/unistd-llvm-2.9-jit.patch"
cd llvm-2.9
./configure --enable-optimized --enable-assertions
make
sudo sh -c 'echo export PATH=\$PATH:'${BASEDIR}'/llvm-2.9/Release+Asserts/bin >> /etc/profile.d/kleevars.sh'
. "/etc/profile.d/kleevars.sh"

# Install stp
echo "Installing stp.."
cd ..
rm -rf "${BASEDIR}/stp-r940" "${BASEDIR}/stp-r940.tgz"
curl -40L 'http://www.doc.ic.ac.uk/~cristic/klee/stp-r940.tgz' > stp-r940.tgz
tar xzfv stp-r940.tgz 
cd stp-r940
#See: #https://github.com/stp/stp/commit/ece1a55fb367bd905078baca38476e35b4df06c3
patch "src/parser/CVC.y" "../patches/CVC.patch"
patch "src/parser/smtlib.y" "../patches/smtlib.patch"
patch "src/parser/smtlib2.y" "../patches/smtlib2.patch"
./scripts/configure --with-prefix=`pwd`/install --with-cryptominisat2
make OPTIMIZE=-O2 CFLAGS_M32= install

# Increasing stack and number of open files limit. 
#ulimit -s unlimited
if ! grep '*\t\thard\tstack\t\tunlimited' "/etc/security/limits.conf"
then
        echo -e '*\t\thard\tstack\t\tunlimited\n*\t\tsoft\tstack\t\tunlimited\n*\t\thard\tnofile\t\t999999\n*\t\tsoft\tnofile\t\t999999' | sudo tee -a "/etc/security/limits.conf"
fi

# Install klee-uclibc
echo "Installing klee-uclibc.."
cd ..
rm -rf "${BASEDIR}/klee-uclibc"
git clone https://github.com/klee/klee-uclibc.git
cd klee-uclibc
./configure --with-llvm-config="$BASEDIR/llvm-2.9/Release+Asserts/bin/llvm-config" --with-cc="$BASEDIR/llvm-gcc4.2-2.9-x86_64-linux/bin/llvm-gcc" --make-llvm-lib
make -j2

# Install klee
echo "Installing klee.."
cd ..
rm -rf "${BASEDIR}/klee"
git clone 'https://github.com/klee/klee.git'
cd klee
./configure --with-llvm="$BASEDIR/llvm-2.9" --with-stp="$BASEDIR/stp-r940/install" --with-uclibc="$BASEDIR/klee-uclibc" --enable-posix-runtime
make ENABLE_OPTIMIZED=1
sudo sh -c 'echo export PATH=\$PATH:'${BASEDIR}'/klee/Release+Asserts/bin >> /etc/profile.d/kleevars.sh'
. "/etc/profile.d/kleevars.sh"

# Run klee tests
echo "Testing klee.."
sudo ln -s /usr/lib/x86_64-linux-gnu /usr/lib64 #Needed for 1 test, _testingUtils.c, crt1.o 
make check
make unittests
