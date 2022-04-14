#!/bin/sh
#
# adapted from:
# https://github.com/RemedyIT/axcioma/blob/master/.github/workflows/linux.yml
#

set -e
set -u

export LANG=C
export WORKSPACE=`realpath ..`
export X11_BASE_ROOT=$WORKSPACE/axcioma
export INSTALL_PREFIX=$X11_BASE_ROOT/stage

source .env_add.sh

set -x

############################################################

export BRIX11_VERBOSE=1
export BRIX11_NUMBER_OF_PROCESSORS=6

############################################################

# TODO: force to build only taox11! CK
rm -rf ciaox11 dancex11

$X11_BASE_ROOT/bin/brix11 bootstrap taox11

$X11_BASE_ROOT/bin/brix11 configure -W aceroot=$ACE_ROOT -W taoroot=$TAO_ROOT -W mpcroot=$MPC_ROOT

# - name: Print brix11 configuration
$X11_BASE_ROOT/bin/brix11 --version
$X11_BASE_ROOT/bin/brix11 env -- configure -P 2>&1 | tee env-configure.log

# FIXME: quickfixes for OSX
# ACE/include/makeinclude/platform_macosx.GNU
platform_file='include $(ACE_ROOT)/include/makeinclude/platform_macosx.GNU'
echo ${platform_file} > ${ACE_ROOT}/include/makeinclude/platform_macros.GNU

# ACE/ace/config.h
# ACE/ace/config-macosx.h
echo '#include "ace/config-macosx.h"' > ${ACE_ROOT}/ace/config.h

# ACE/bin/MakeProjectCreator/config/default.features
echo 'ipv6=1' > ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
echo 'versioned_namespace=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
echo 'acetaompc=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
echo 'inline=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
echo 'optimize=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features

# generate all makefiles
# see workspace.mwc
perl ${TAOX11_ROOT}/bin/mwc.pl -type gnuace ${X11_BASE_ROOT}/workspace.mwc -workers ${BRIX11_NUMBER_OF_PROCESSORS}

#see taox11/taox11.mpc
#and ACE_TAO/ACE/ace/ace_for_tao.mpc
#NO! bin/brix11 gen build workspace.mwc

# make all
make -j ${BRIX11_NUMBER_OF_PROCESSORS} 2>&1 | tee build-all.log
$X11_BASE_ROOT/bin/brix11 make -N -d ${TAOX11_ROOT}/examples -- make -N -d ${TAOX11_ROOT}/orbsvcs/tests -- make -N -d ${TAOX11_ROOT}/tests 2>&1 | tee -a build-all.log

# make tests
$X11_BASE_ROOT/bin/brix11 run list -l taox11/bin/taox11_tests.lst -r taox11 2>&1 | tee run-list.log

# install
make -j ${BRIX11_NUMBER_OF_PROCESSORS} install 2>&1 | tee make-install.log

exit 0
