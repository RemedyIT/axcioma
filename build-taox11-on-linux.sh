#!/bin/sh
set -e
set -u

export WORKSPACE=/home/klein_cl/Workspace/cpp
export X11_BASE_ROOT=$WORKSPACE/axcioma

export ACE_ROOT=$X11_BASE_ROOT/ACE/ACE
export CIAOX11_ROOT=$X11_BASE_ROOT/ciaox11
export DANCEX11_ROOT=$X11_BASE_ROOT/dancex11
export LD_LIBRARY_PATH=$X11_BASE_ROOT/lib:$X11_BASE_ROOT/ACE/ACE/lib:/usr/lib:/usr/local/lib/python3.8/site-packages:$X11_BASE_ROOT/ciaox11/lib:$X11_BASE_ROOT/dancex11/lib
export MPC_BASE=$X11_BASE_ROOT/taox11/bin/MPC
export MPC_ROOT=$X11_BASE_ROOT/ACE/MPC
export PATH=$X11_BASE_ROOT/dancex11/bin:$X11_BASE_ROOT/ciaox11/bin:$X11_BASE_ROOT/bin:$X11_BASE_ROOT/taox11/bin:/home/klein_cl/.local/bin:/usr/local/lib/python3.8/site-packages:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export RIDL_BE_PATH=:$X11_BASE_ROOT/taox11:$X11_BASE_ROOT/ciaox11:$X11_BASE_ROOT/ciaox11/connectors/psdd4ccm
export RIDL_BE_SELECT=ccmx11
export RIDL_ROOT=$X11_BASE_ROOT/ridl/lib
export SSL_ROOT=/usr
export TAOX11_ROOT=$X11_BASE_ROOT/taox11
export TAO_ROOT=$X11_BASE_ROOT/ACE/TAO
export XERCESCROOT=/usr
export ZLIB_ROOT=/usr
export INSTALL_PREFIX=$PWD/stage

set -x

bin/brix11 configure -W aceroot=$ACE_ROOT -W taoroot=$TAO_ROOT -W mpcroot=$MPC_ROOT

bin/brix11 env -- configure -P 2>&1 | tee configure.log

bin/brix11 gen build workspace.mwc -- gen build $TAOX11_ROOT/examples -- gen build $TAOX11_ROOT/orbsvcs/tests -- gen build $TAOX11_ROOT/tests

bin/brix11 run list -l taox11/bin/taox11_tests.lst -r taox11 2>&1 | tee run-test.log

make -j -C ${TAOX11_ROOT} install

