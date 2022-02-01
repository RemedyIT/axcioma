#!/bin/bash
set -e
set -u

export WORKSPACE=`realpath ..`
export X11_BASE_ROOT=$WORKSPACE/axcioma
export INSTALL_PREFIX=$X11_BASE_ROOT/stage

source .env_add.sh

set -x

#TODO: force to build only taox11! CK
rm -rf ciaox11 dancex11

bin/brix11 bootstrap taox11

bin/brix11 configure -W aceroot=$ACE_ROOT -W taoroot=$TAO_ROOT -W mpcroot=$MPC_ROOT

bin/brix11 env -- configure -P 2>&1 | tee configure.log

bin/brix11 gen build workspace.mwc -- gen build ${TAOX11_ROOT}/examples -- gen build ${TAOX11_ROOT}/orbsvcs/tests -- gen build ${TAOX11_ROOT}/tests

bin/brix11 make -N -d ${X11_BASE_ROOT} -- make -N -d ${TAOX11_ROOT}/examples -- make -N -d ${TAOX11_ROOT}/orbsvcs/tests -- make -N -d ${TAOX11_ROOT}/tests 2>&1 | tee make-all.log

#TODO: workaround to prevent problems with WSL and windows firewall! CK
egrep "^127.0.1.1\s+$HOSTNAME" /etc/hosts && echo "change to 127.0.0.1!" && exit 1
bin/brix11 run list -l taox11/bin/taox11_tests.lst -r taox11 2>&1 | tee run-test.log

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
cd ..
mkdir -p orbsvcs/naming_server
cp -p naming_server/* orbsvcs/naming_server
rm -rf x11 naming_server
popd

#FIXME: show install garbage! CK
find ${INSTALL_PREFIX}/include -type d -name home -prune | xargs tree
#TODO: remove garbage! CK
find ${INSTALL_PREFIX}/include -type d -name home -prune | xargs rm -rf

