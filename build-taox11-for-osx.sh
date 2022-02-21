#!/bin/sh
#
# adapted from:
# https://github.com/RemedyIT/axcioma/blob/master/.github/workflows/linux.yml
#

set -e
set -u

export BOOST_ROOT=/usr/local
export BZIP2_ROOT=/usr/local
#TODO ls -l ${BZIP2_ROOT}/include/bzlib.h
export CPPUNIT_ROOT=/usr/local
export LOG4CPLUS_ROOT=/usr/local
export LZO1_ROOT=/usr/local
export LZO2_ROOT=/usr/local
export MPI_ROOT=/usr/local
export PCRE_ROOT=/usr/local
export PNG_ROOT=/usr/local
export XERCESCROOT=/usr/local
ls -l ${XERCESCROOT}/include/xercesc/parsers/SAXParser.hpp
export ZLIB_ROOT=/usr/local
#TODO -l ${ZLIB_ROOT}/include/bzlib.h
export ZMQ_ROOT=/usr/local
ls -l ${ZMQ_ROOT}/include/zmq.h
###############################
#XXX export SSL_ROOT='/usr/local/Cellar/openssl@1.1/1.1.1m'
#XXX ls -l ${SSL_ROOT}/include/openssl/ssl.h

set -x

############################################################

export X11_BASE_ROOT=${PWD}
export INSTALL_PREFIX=${X11_BASE_ROOT}/stage

export DOC_ROOT=${X11_BASE_ROOT}/ACE
export ACE_ROOT=${X11_BASE_ROOT}/ACE/ACE
export MPC_ROOT=${X11_BASE_ROOT}/ACE/MPC
export TAO_ROOT=${X11_BASE_ROOT}/ACE/TAO
export TAOX11_ROOT=${X11_BASE_ROOT}/taox11
export MPC_BASE=${TAOX11_ROOT}/bin/MPC

export RIDL_ROOT=${X11_BASE_ROOT}/ridl
export RIDL_BE_PATH=${TAOX11_ROOT}
#NO! :/Users/clausklein/Workspace/cpp/axcioma/ciaox11:/Users/clausklein/Workspace/cpp/axcioma/ciaox11/connectors/psdd4ccm
export RIDL_BE_SELECT=c++11

#NO! export CIAOX11_ROOT=${X11_BASE_ROOT}/ciaox11
#NO! export DANCEX11_ROOT=${X11_BASE_ROOT}/dancex11
#NO! export DDS_ROOT=${X11_BASE_ROOT}/OpenDDS

export BRIX11_VERBOSE=1
export BRIX11_NUMBER_OF_PROCESSORS=6

############################################################

$X11_BASE_ROOT/bin/brix11 configure -W aceroot=$ACE_ROOT -W taoroot=$TAO_ROOT -W mpcroot=$MPC_ROOT
#XXX -W openddsroot=$DDS_ROOT -W xercescroot=$XERCESCROOT -W zqmroot=$ZMQ_ROOT -W sslroot=$SSL_ROOT

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

#TODO echo 'c++17=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'xerces2=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'opendds=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'ndds=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'zlib=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'lzo1=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'lzo2=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'bzip2=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'boost=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#TODO echo 'ace_for_tao=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'multi_topic=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'ssl=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features
#XXX echo 'zmq=1' >> ${ACE_ROOT}/bin/MakeProjectCreator/config/default.features

# generate all makefiles
# see workspace.mwc
perl ${TAOX11_ROOT}/bin/mwc.pl -type gnuace ${X11_BASE_ROOT}/workspace.mwc -workers ${BRIX11_NUMBER_OF_PROCESSORS}
perl ${TAOX11_ROOT}/bin/mwc.pl -type gnuace ${TAO_ROOT}/TAO_ACE.mwc -workers ${BRIX11_NUMBER_OF_PROCESSORS}

#see taox11/taox11.mpc
#and ACE_TAO/ACE/ace/ace_for_tao.mpc
#NO! bin/brix11 gen build workspace.mwc

# make all
make -j ${BRIX11_NUMBER_OF_PROCESSORS} 2>&1 | tee build-all.log
#XXX $X11_BASE_ROOT/bin/brix11 make -N -d ${TAOX11_ROOT} 2>&1 | tee build-all.log
$X11_BASE_ROOT/bin/brix11 make -N -d ${TAOX11_ROOT}/examples -- make -N -d ${TAOX11_ROOT}/orbsvcs/tests -- make -N -d ${TAOX11_ROOT}/tests 2>&1 | tee -a build-all.log
#XXX make -j ${BRIX11_NUMBER_OF_PROCESSORS} -C ${TAO_ROOT} 2>&1 | tee -a build-all.log

# make tests
$X11_BASE_ROOT/bin/brix11 run list -l taox11/bin/taox11_tests.lst -r taox11 2>&1 | tee run-list.log

# install
make -j ${BRIX11_NUMBER_OF_PROCESSORS} install 2>&1 | tee make-install.log
#XXX make -j ${BRIX11_NUMBER_OF_PROCESSORS} -C ${TAOX11_ROOT} install
#XXX make -j ${BRIX11_NUMBER_OF_PROCESSORS} -C ${TAO_ROOT} install

exit 0
