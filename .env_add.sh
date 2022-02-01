#!/bin/sh

#XXX set -u
#XXX set -e

export X11_BASE_ROOT=$PWD
export TAOX11_ROOT=$X11_BASE_ROOT/taox11
export ACE_ROOT=$X11_BASE_ROOT/ACE/ACE
export TAO_ROOT=$X11_BASE_ROOT/ACE/TAO

export MPC_BASE=$TAOX11_ROOT/bin/MPC
export MPC_ROOT=$X11_BASE_ROOT/ACE/MPC

export LD_LIBRARY_PATH=$X11_BASE_ROOT/lib:$ACE_ROOT/lib:/usr/lib:
export PATH=$X11_BASE_ROOT/bin:$TAOX11_ROOT/bin:$ACE_ROOT/bin:$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

export RIDL_BE_PATH=:$TAOX11_ROOT/
export RIDL_BE_SELECT=c++11
export RIDL_ROOT=$X11_BASE_ROOT/ridl/lib

export BZIP2_ROOT=/usr
export SSL_ROOT=/usr
export ZLIB_ROOT=/usr

