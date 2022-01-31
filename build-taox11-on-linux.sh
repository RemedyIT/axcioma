#!/bin/bash
set -e
set -u

export WORKSPACE=`realpath ..`
export X11_BASE_ROOT=$WORKSPACE/axcioma
export INSTALL_PREFIX=$X11_BASE_ROOT/stage

export ACE_ROOT=$X11_BASE_ROOT/ACE/ACE
export TAO_ROOT=$X11_BASE_ROOT/ACE/TAO
export TAOX11_ROOT=$X11_BASE_ROOT/taox11

# export CIAOX11_ROOT=$X11_BASE_ROOT/ciaox11
# export DANCEX11_ROOT=$X11_BASE_ROOT/dancex11

export LD_LIBRARY_PATH=$X11_BASE_ROOT/lib:$ACE_ROOT/lib:/usr/local/lib:/usr/lib:$PYTHONPATH
#NO! export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$X11_BASE_ROOT/ciaox11/lib:$X11_BASE_ROOT/dancex11/lib
export MPC_BASE=$TAOX11_ROOT/bin/MPC
export MPC_ROOT=$X11_BASE_ROOT/ACE/MPC
export PATH=$X11_BASE_ROOT/bin:$TAOX11_ROOT/bin:$HOME/.local/bin:$PYTHONPATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#NO! export PATH=$X11_BASE_ROOT/dancex11/bin:$X11_BASE_ROOT/ciaox11/bin:$PATH
export RIDL_BE_PATH=$TAOX11_ROOT
#NO! export RIDL_BE_PATH=$RIDL_BE_PATH:$X11_BASE_ROOT/ciaox11:$X11_BASE_ROOT/ciaox11/connectors/psdd4ccm
export RIDL_BE_SELECT=c++11
export RIDL_ROOT=$X11_BASE_ROOT/ridl/lib

export XERCESCROOT=/usr
export ZLIB_ROOT=/usr
export SSL_ROOT=/usr

set -x

bin/brix11 configure -W aceroot=$ACE_ROOT -W taoroot=$TAO_ROOT -W mpcroot=$MPC_ROOT

bin/brix11 env -- configure -P 2>&1 | tee configure.log

bin/brix11 gen build workspace.mwc -- gen build ${TAOX11_ROOT}/examples -- gen build ${TAOX11_ROOT}/orbsvcs/tests -- gen build ${TAOX11_ROOT}/tests

bin/brix11 make -N -d ${X11_BASE_ROOT} -- make -N -d ${TAOX11_ROOT}/examples -- make -N -d ${TAOX11_ROOT}/orbsvcs/tests -- make -N -d ${TAOX11_ROOT}/tests 2>&1 | tee make-all.log

#FIXME: problems with WSL and windows firewall! CK
#TODO bin/brix11 run list -l taox11/bin/taox11_tests.lst -r taox11 2>&1 | tee run-test.log

make -j -C ${X11_BASE_ROOT} install 2>&1 | tee make-install.log

#TODO: should be not needed? CK
# make -j -C ${TAOX11_ROOT} install
# make -j -C ${TAO_ROOT} -k install
# make -j -C ${ACE_ROOT} -k install

#FIXME: quickfix to make include tree usable! CK
# see taox11/tao/x11/taox11.mpc
pushd ${INSTALL_PREFIX}/include/x11
cp -p *.h ../tao/x11
cp -p *.cpp ../tao/x11
popd

find ${INSTALL_PREFIX}/include -type d -name home -prune | xargs tree
#TODO: remove garbage! CK
#find ${INSTALL_PREFIX}/include -type d -name home -prune | xargs rm -rf


