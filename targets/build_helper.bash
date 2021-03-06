################################################################################
#   OpenAirInterface
#   Copyright(c) 1999 - 2014 Eurecom
#
#    OpenAirInterface is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#
#    OpenAirInterface is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with OpenAirInterface.The full GNU General Public License is
#    included in this distribution in the file called "COPYING". If not,
#    see <http://www.gnu.org/licenses/>.
#
#  Contact Information
#  OpenAirInterface Admin: openair_admin@eurecom.fr
#  OpenAirInterface Tech : openair_tech@eurecom.fr
#  OpenAirInterface Dev  : openair4g-devel@eurecom.fr
#
#  Address      : Eurecom, Campus SophiaTech, 450 Route des Chappes, CS 50193 - 06904 Biot Sophia Antipolis cedex, FRANCE
#
################################################################################
# file build_helper.bash
# brief
# author Lionel Gauthier and Navid Nikaein
# company Eurecom
# email: lionel.gauthier@eurecom.fr and navid.nikaein@eurecom.fr 
#
#######################################
#            Helper Func
######################################

declare ROOT_UID=0
declare E_NOTROOT=67
declare NUM_CPU=`cat /proc/cpuinfo | grep processor | wc -l`
declare OAI_INSTALLED=1
declare PWD=`pwd`
declare USER=`whoami`
declare BUILD_FROM_MAKEFILE=0
declare SUDO=''
declare PW=''
declare UBUNTU_REL=`lsb_release -r | cut  -f2`
declare UBUNTU_REL_NAME=`lsb_release -cs`

set_build_from_makefile(){
    BUILD_FROM_MAKEFILE=$1   
}

check_for_root_rights() {
    
  #  if [[ $EUID -ne $ROOT_EUID ]]; then
    if [ $USER != "root" ]; then
        SUDO="sudo -E "
        echo "Run as a sudoers" 
        return 1
    else 
        echo  "Run as a root" 
        return 0
    fi
}

test_install_package() {
  # usage: test_install_package package_name
 
 if [ $# -eq 1 ]; then
      dpkg -s "$1" > /dev/null 2>&1 && {
          echo "$1 is installed." 
      } || {
          echo "$1 is not installed." 
          OAI_INSTALLED=0
          $SUDO apt-get install -y $@
      }
  fi
}

test_uninstall_package() {
  
 if [ $# -eq 1 ]; then
      dpkg -s "$1" > /dev/null 2>&1 && {
          $SUDO apt-get remove --assume-yes $1  
          echo "$1 is uninstalled." 
      } || {
          echo "$1 is not installed." 
      }
  fi
}
test_command_install_script() {
  # usage: test_command_install_script searched_binary script_to_be_invoked_if_binary_not_found
  command -v $1 >/dev/null 2>&1 || { echo_warning "Program $1 is not installed. Trying installing it." >&2; bash $2; command -v $1 >/dev/null 2>&1 || { echo_fatal "Program $1 is not installed. Aborting." >&2; };}
  echo_success "$1 available"
}


check_for_machine_type(){
    MACHINE_TYPE=`uname -m`
    if [ ${MACHINE_TYPE} = "x86_64" ]; then
        return 64  # 64-bit stuff here
    else
        if [ ${MACHINE_TYPE} = "i686" ]; then
            return 32 # 32-bit stuff here
        else 
            return -1 
        fi
    fi
}

####################################################
## OAI related functions
#####################################################

####################################################
# 1. install the required packages 
####################################################

make_certs(){

 # for certtificate generation
    rm -rf demoCA
    mkdir -m 777 -p demoCA
    echo 01 > demoCA/serial
    touch demoCA/index.txt
    
    echo "creating the certificate"
    
    user=$(whoami)
    HOSTNAME=$(hostname -f)

    echo "Creating certificate for user '$HOSTNAME'"
    
# CA self certificate
    openssl req  -new -batch -x509 -days 3650 -nodes -newkey rsa:1024 -out cacert.pem -keyout cakey.pem -subj /CN=eur/C=FR/ST=PACA/L=Aix/O=Eurecom/OU=CM
    
   # openssl genrsa -out user.key.pem 1024
    openssl genrsa -out hss.key.pem 1024
    #openssl req -new -batch -out user.csr.pem -key user.key.pem -subj /CN=$HOSTNAME.eur/C=FR/ST=PACA/L=Aix/O=Eurecom/OU=CM
    openssl req -new -batch -out hss.csr.pem -key hss.key.pem -subj /CN=hss.eur/C=FR/ST=PACA/L=Aix/O=Eurecom/OU=CM
    openssl ca -cert cacert.pem -keyfile cakey.pem -in hss.csr.pem -out hss.cert.pem -outdir . -batch
    
    if [ ! -d /usr/local/etc/freeDiameter ];  then
        echo "Creating non existing directory: /usr/local/etc/freeDiameter/"
        $SUDO mkdir /usr/local/etc/freeDiameter/
    fi
    
    echo "Copying *.pem to /usr/local/etc/freeDiameter/"
    $SUDO cp *.pem /usr/local/etc/freeDiameter/
    mv *.pem bin/
    
# openssl genrsa -out ubuntu.key.pem 1024
# openssl req -new -batch -x509 -out ubuntu.csr.pem -key ubuntu.key.pem -subj /CN=ubuntu.localdomain/C=FR/ST=BdR/L=Aix/O=fD/OU=Tests
# openssl ca -cert cacert.pem -keyfile cakey.pem -in ubuntu.csr.pem -out ubuntu.cert.pem -outdir . -batch

}

check_install_nettle(){
    if [ ! -f ./.lock_oaibuild ]; then 
	if [ $UBUNTU_REL = "12.04" ]; then 
	    test_uninstall_package nettle-dev
	    test_uninstall_package nettle-bin
	
	    if [ ! -d /usr/local/src/ ]; then
		echo "/usr/local/src/ doesn't exist please create one"
		exit -1
	    fi
	    
	    if [ ! -w /usr/local/src/ ];  then
		echo "You don't have permissions to write to /usr/local/src/, installing as a sudoer"
		#	exit -1
	    fi
	    
	    cd /usr/local/src/
	    
	    echo "Downloading nettle archive"
	    
	    if [ -f nettle-2.5.tar.gz ]; then
		$SUDO rm -f nettle-2.5.tar.gz
	    fi
	    if [ -f nettle-2.5.tar ]; then
		$SUDO rm -f nettle-2.5.tar
	    fi
	    if [ -d nettle-2.5 ];  then
		$SUDO rm -rf nettle-2.5/
	    fi
	    
	    
	    $SUDO wget ftp://ftp.lysator.liu.se/pub/security/lsh/nettle-2.5.tar.gz 
	    $SUDO gunzip nettle-2.5.tar.gz 
	    $SUDO echo "Uncompressing nettle archive"
	    $SUDO tar -xf nettle-2.5.tar
	    cd nettle-2.5/
	    $SUDO ./configure --disable-openssl --enable-shared --prefix=/usr 
	    if [ $? -ne 0 ]; then
		exit -1
	    fi
	    echo "Compiling nettle"
	    $SUDO make -j $NUM_CPU  
	    $SUDO make check 
	    $SUDO make install 
	    cd ../
	fi
    fi
}

check_install_freediamter(){
    
    if [ $UBUNTU_REL = "12.04" ]; then 

	if [ ! -d /usr/local/src/ ]; then
	    echo "/usr/local/src/ doesn't exist please create one"
	    exit -1
	fi
	
	if [ ! -w /usr/local/src/ ];  then
	    echo "You don't have permissions to write to /usr/local/src/, installing as a sudoer"
#	exit -1
	fi
	
	cd /usr/local/src/
	
	echo "Downloading nettle archive"
	
	if [ -f nettle-2.5.tar.gz ]; then
	    $SUDO rm -f nettle-2.5.tar.gz
	fi
	if [ -f nettle-2.5.tar ]; then
	    $SUDO rm -f nettle-2.5.tar
	fi
	if [ -d nettle-2.5 ];  then
	    $SUDO rm -rf nettle-2.5/
	fi
	
	
	$SUDO wget ftp://ftp.lysator.liu.se/pub/security/lsh/nettle-2.5.tar.gz 
	$SUDO gunzip nettle-2.5.tar.gz 
	$SUDO echo "Uncompressing nettle archive"
	$SUDO tar -xf nettle-2.5.tar
	cd nettle-2.5/
	$SUDO ./configure --disable-openssl --enable-shared --prefix=/usr 
	if [ $? -ne 0 ]; then
	    exit -1
	fi
	echo "Compiling nettle"
	$SUDO make -j $NUM_CPU  
	$SUDO make check 
	$SUDO make install 
	cd ../
    fi
    
    echo "Downloading gnutls archive"
    
    if [ -f gnutls-3.1.0.tar.xz ];  then
	$SUDO rm -f gnutls-3.1.0.tar.xz
    fi
    if [ -d gnutls-3.1.0/ ];  then
	$SUDO rm -rf gnutls-3.1.0/
    fi
    
    test_uninstall_package libgnutls-dev
    
    $SUDO wget ftp://ftp.gnutls.org/gcrypt/gnutls/v3.1/gnutls-3.1.0.tar.xz 
    $SUDO tar -xf gnutls-3.1.0.tar.xz
    echo "Uncompressing gnutls archive ($PWD)"
    cd gnutls-3.1.0/
    $SUDO ./configure --prefix=/usr
    if [ $? -ne 0 ];   then
	exit -1
    fi
    echo "Compiling gnutls"
    $SUDO make -j $NUM_CPU 
    $SUDO make install 
    cd ../
    
    echo "Downloading freeDiameter archive"
    
    if [ -f 1.1.5.tar.gz ];  then
	$SUDO rm -f 1.1.5.tar.gz
    fi
    if [ -d freeDiameter-1.1.5/ ];   then
	$SUDO rm -rf freeDiameter-1.1.5/
    fi
    
    $SUDO wget http://www.freediameter.net/hg/freeDiameter/archive/1.1.5.tar.gz 
    $SUDO tar -xzf 1.1.5.tar.gz 
    echo "Uncompressing freeDiameter archive"
    cd freeDiameter-1.1.5
    $SUDO patch -p1 < $OPENAIRCN_DIR/S6A/freediameter/freediameter-1.1.5.patch 
    $SUDO mkdir build
    cd build
    $SUDO cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr ../ 
    if [ $? -ne 0 ];  then
	exit -1
    fi
    echo "Compiling freeDiameter"
    $SUDO make -j $NUM_CPU 
#make help
    $SUDO make test 
    $SUDO sudo make install 
  
#    make_certs
   
}

check_epc_s6a_certificate() {
    cnt=0
    if [ -d /usr/local/etc/freeDiameter ]
    then
        if [ -f /usr/local/etc/freeDiameter/user.cert.pem ]
        then
            full_hostname=`cat /usr/local/etc/freeDiameter/user.cert.pem | grep "Subject" | grep "CN" | cut -d '=' -f6`
            if [ a$full_hostname == a`hostname`.${1:-'eur'} ]
            then
                echo_success "EPC S6A: Found valid certificate in /usr/local/etc/freeDiameter"
                return 1
            fi
        fi
    fi
    echo_error "EPC S6A: Did not find valid certificate in /usr/local/etc/freeDiameter"
    echo_warning "EPC S6A: generatting new certificate in /usr/local/etc/freeDiameter..."
    cd $OPENAIRCN_DIR/S6A/freediameter
    ./make_certs.sh ${1:-'eur'}
    if [ $cnt = 0 ] ; then
        cnt=1
        check_epc_s6a_certificate ${1:-'eur'}
    fi
    return 1
}


check_s6a_certificate() {
    cnt=0
    if [ -d /usr/local/etc/freeDiameter ]; then
        if [ -f /usr/local/etc/freeDiameter/hss.cert.pem ];  then
            full_hostname=`cat /usr/local/etc/freeDiameter/hss.cert.pem | grep "Subject" | grep "CN" | cut -d '=' -f6`
#	    if [ $full_hostname = `hostname`.eur ];   then
	    if [ $full_hostname = hss.eur ];   then
                echo_success "S6A: Found valid certificate in /usr/local/etc/freeDiameter"
                return 0
            fi
        fi
    fi
    echo_error "S6A: Did not find valid certificate in /usr/local/etc/freeDiameter"
    echo_warning "S6A: generatting new certificate in /usr/local/etc/freeDiameter..."
    cd $OPENAIRCN_DIR/S6A/freediameter
    make_certs
    if [ $cnt = 0 ] ; then
        cnt=1
        check_s6a_certificate
    fi
    return 1
}

check_install_usrp_uhd_driver(){
    if [ ! -f /etc/apt/sources.list.d/ettus.list ] ; then 
        $SUDO bash -c 'echo "deb http://files.ettus.com/binaries/uhd/repo/uhd/ubuntu/`lsb_release -cs` `lsb_release -cs` main" >> /etc/apt/sources.list.d/ettus.list'
        $SUDO apt-get update
    fi 
    $SUDO apt-get install -t $UBUNTU_REL_NAME uhd
    test_install_package python 
    test_install_package libboost-all-dev 
    test_install_package libusb-1.0-0-dev
    #test_install_package uhd
}

check_install_oai_software() {
    
    if [ ! -f ./.lock_oaibuild ]; then 
        $SUDO apt-get update
        if [ $UBUNTU_REL = "12.04" ]; then 
            test_uninstall_package nettle-dev
            test_uninstall_package nettle-bin
        else 
            test_install_package nettle-dev
            test_install_package nettle-bin
        fi 
        test_install_package autoconf 
        test_install_package automake 
        test_install_package bison 
        test_install_package build-essential
        test_install_package dialog
        test_install_package flex 
        test_install_package gawk
        test_install_package gcc
        test_install_package gdb 
        test_install_package make
        test_install_package cmake
        test_install_package openssh-client
        test_install_package openssh-server
        sudo service ssh start
        test_install_package unzip 
        test_install_package autoconf
        test_install_package automake
        test_install_package bison
        test_install_package build-essential
        test_install_package check
        test_install_package ethtool
        test_install_package flex
        test_install_package g++
        test_install_package gawk
        test_install_package gcc
        test_install_package gccxml
        test_install_package gdb 
        test_install_package guile-2.0-dev
        test_install_package iperf
        test_install_package iproute
        test_install_package iptables
        test_install_package libatlas-base-dev
        test_install_package libatlas-dev
        test_install_package libblas3gf
        test_install_package libblas-dev
#	if [ $MACHINE_ARCH = 64 ]; then
            test_install_package libconfig8-dev
#	else
#            test_install_package libconfig-dev
#	fi
        test_install_package libforms-bin
        test_install_package libforms-dev
        test_install_package libgcrypt11-dev
        test_install_package libgmp-dev
        test_install_package libgtk-3-dev
        test_install_package libidn11-dev
        test_install_package libidn2-0-dev
        test_install_package libpgm-dev
        test_install_package libpgm-5.1-0
        test_install_package libpthread-stubs0-dev
        test_install_package libsctp1
        test_install_package libsctp-dev
        test_install_package libtasn1-3-dev
        test_install_package libxml2
        test_install_package libxml2-dev
#       test_install_package linux-headers-`uname -r`
        test_install_package openssl
        test_install_package libssl-dev 
        test_install_package pkg-config
        test_install_package python-dev
        test_install_package python-pexpect
        test_install_package sshfs
        test_install_package subversion
        test_install_package valgrind
        test_install_package doxygen
        test_install_package graphviz
	
# TODO: install the USRP UHD packages 
#        if [ $1 = "USRP" ] ; then 
	
#        test_install_package libboost-all-dev
	
        if [ $OAI_INSTALLED = 1 ]; then 
            touch ./.lock_oaibuild
        fi 
    
     else
        echo_info "All the required packages installed: skip"
    fi 
    
}

check_install_hss_software() {
    if [ ! -f ./.lock_oaibuild ]; then 
	$SUDO apt-get update
	if [ $UBUNTU_REL = "12.04" ]; then 
	    test_uninstall_package nettle-dev
	    test_uninstall_package nettle-bin
        else 
            test_install_package nettle-dev
            test_install_package nettle-bin
	fi 
	test_install_package autoconf 
	test_install_package automake 
	test_install_package bison 
	test_install_package build-essential
	test_install_package cmake
	test_install_package cmake-curses-gui 
    test_install_package dialog
    test_install_package dkms
	test_install_package flex 
	test_install_package gawk
	test_install_package gcc
	test_install_package gdb 
	test_install_package guile-2.0-dev 
	test_install_package g++
	test_install_package libgmp-dev 
	test_install_package libgcrypt11-dev 
	test_install_package libidn11-dev 
	test_install_package libidn2-0-dev 
	test_install_package libmysqlclient-dev 
	test_install_package libtasn1-3-dev 
	test_install_package libsctp1 
	test_install_package libsctp-dev 
	test_install_package libxml2-dev 
#	test_install_package linux-headers-`uname -r` 
	test_install_package make
	test_install_package mysql-client-core-5.5 
	test_install_package mysql-server-core-5.5 
	test_install_package mysql-server-5.5 
	test_install_package openssh-client
	test_install_package openssh-server
        sudo service ssh start
	test_install_package phpmyadmin
	test_install_package python-dev 
	test_install_package sshfs
	test_install_package swig 
	test_install_package unzip 
#	test_install_package nettle-bin
#	test_install_package nettle-dev
	test_install_package valgrind 

	if [ $OAI_INSTALLED = 1 ]; then 
	    touch ./.lock_oaibuild
	fi 
	
    else
	echo_info "All the required packages installed: skip"
    fi 

}

check_install_epc_software() {

    if [ ! -f ./.lock_oaibuild ]; then 
        $SUDO apt-get update
        if [ $UBUNTU_REL = "12.04" ]; then 
            test_uninstall_package nettle-dev
            test_uninstall_package nettle-bin
        else 
            test_install_package nettle-dev
            test_install_package nettle-bin
        fi 
        test_install_package autoconf
        test_install_package automake
        test_install_package bison
        test_install_package build-essential
        test_install_package check
        test_install_package cmake
        test_install_package cmake-curses-gui
        test_install_package dialog
        test_install_package ethtool
        test_install_package flex
        test_install_package g++
        test_install_package gawk
        test_install_package gcc
        test_install_package gccxml
        test_install_package gdb 
        test_install_package guile-2.0-dev
        test_install_package gtkwave
        test_install_package iperf
        test_install_package iproute
        test_install_package iptables
        test_install_package libatlas-base-dev
        test_install_package libatlas-dev
        test_install_package libblas
        test_install_package libblas-dev
#       if [ $MACHINE_ARCH = 64 ]; then
            test_install_package libconfig8-dev
#        else
#            test_install_package libconfig-dev
#       fi
        test_install_package libforms-bin
        test_install_package libforms-dev
        test_install_package libgcrypt11-dev
        test_install_package libgmp-dev
        test_install_package libgtk-3-dev
        test_install_package libidn11-dev
        test_install_package libidn2-0-dev
        test_install_package libmysqlclient-dev
        test_install_package libpgm-dev
        test_install_package libpthread-stubs0-dev
        test_install_package libsctp1
        test_install_package libsctp-dev
        test_install_package libtasn1-3-dev
        test_install_package libxml2
        test_install_package libxml2-dev
#        test_install_package linux-headers-`uname -r`
        test_install_package make
        test_install_package openssh-client
        test_install_package openssh-server
        $SUDO service ssh start
        test_install_package openssl
        test_install_package openvpn
        test_install_package pkg-config
        test_install_package python-dev
        test_install_package sshfs
        test_install_package subversion
        test_install_package swig
        test_install_package tshark
        test_install_package uml-utilities
        test_install_package unzip
        test_install_package valgrind
        test_install_package vlan
        test_install_package libtool 
	
        if [ $OAI_INSTALLED = 1 ]; then 
            touch ./.lock_oaibuild
        fi 
    
    else
        echo_info "All the required packages installed: skip"
    fi 

}

check_install_asn1c(){
    
    test_command_install_script   "asn1c" "$OPENAIRCN_DIR/SCRIPTS/install_asn1c_0.9.24.modified.bash $SUDO"
    
    # One mor check about version of asn1c
    ASN1C_COMPILER_REQUIRED_VERSION_MESSAGE="ASN.1 Compiler, v0.9.24"
    ASN1C_COMPILER_VERSION_MESSAGE=`asn1c -h 2>&1 | grep -i ASN\.1\ Compiler`
    ##ASN1C_COMPILER_VERSION_MESSAGE=`trim $ASN1C_COMPILER_VERSION_MESSAGE`
    if [ "$ASN1C_COMPILER_VERSION_MESSAGE" != "$ASN1C_COMPILER_REQUIRED_VERSION_MESSAGE" ]; then
      #  diff <(echo -n "$ASN1C_COMPILER_VERSION_MESSAGE") <(echo -n "$ASN1C_COMPILER_REQUIRED_VERSION_MESSAGE")
        echo_error "Version of asn1c is not the required one, do you want to install the required one (overwrite installation) ? (Y/n)"
        echo_error "$ASN1C_COMPILER_VERSION_MESSAGE"
        while read -r -n 1 -s answer; do
            if [[ $answer = [YyNn] ]]; then
                [[ $answer = [Yy] ]] && $OPENAIRCN_DIR/SCRIPTS/install_asn1c_0.9.24.modified.bash $SUDO
                [[ $answer = [Nn] ]] && echo_error "Version of asn1c is not the required one, exiting." && exit 1
                break
            fi
        done
    fi
    
}

#################################################
# 2. compile 
################################################
compile_hss() {
    cd $OPENAIRCN_DIR/OPENAIRHSS
    OBJ_DIR=`find . -maxdepth 1 -type d -iname obj*`
    if [ $1 = 1 ]; then
        echo_info "build a clean EPC"
        bash_exec "rm -rf obj"
    fi
    if [ ! -n "$OBJ_DIR" ]; then
        OBJ_DIR="objs"
        bash_exec "mkdir -m 777 ./$OBJ_DIR"
        echo_success "Created $OBJ_DIR directory"
    else
        OBJ_DIR=`basename $OBJ_DIR`
    fi
    if [ ! -f $OBJ_DIR/Makefile ]; then
        if [ ! -n "m4" ]; then
            mkdir -m 777 m4
        fi
        echo_success "Invoking autogen"
        bash_exec "./autogen.sh"
        cd ./$OBJ_DIR
        echo_success "Invoking configure"
        ../configure 
    else
        cd ./$OBJ_DIR
    fi
    if [ -f Makefile ];  then
        echo_success "Compiling..."
        make -j $NUM_CPU
        if [ $? -ne 0 ]; then
            echo_error "Build failed, exiting"
            return 1
	else 
	    cp -f ./openair-hss $OPENAIR_TARGETS/bin
	    return 0
        fi
    else
        echo_error "Configure failed, exiting"
        return 1
    fi
}


compile_epc() {
    cd $OPENAIRCN_DIR
    if [ $1 = 1 ]; then
        echo_info "build a clean EPC"
        bash_exec "rm -rf obj"
    fi
    OBJ_DIR=`find . -maxdepth 1 -type d -iname obj*`
    if [ ! -n "$OBJ_DIR" ]; then
        OBJ_DIR="objs"
        bash_exec "mkdir -m 777 ./$OBJ_DIR"
        echo_success "Created $OBJ_DIR directory"
    else
        OBJ_DIR=`basename $OBJ_DIR`
    fi
    if [ ! -f $OBJ_DIR/Makefile ]; then
        if [ ! -n "m4" ]; then
            mkdir -m 777 m4
        fi
        bash_exec "autoreconf -i -f"
        echo_success "Invoking autogen"
        bash_exec "libtoolize"        
        bash_exec "./autogen.sh"
        cd ./$OBJ_DIR
        echo_success "Invoking configure"
        if [ $DEBUG -ne 0 ]; then 
            ../configure --enable-debug --enable-standalone-epc --enable-gtp1u-in-kernel LDFLAGS=-L/usr/local/lib
        else
            ../configure                --enable-standalone-epc --enable-gtp1u-in-kernel LDFLAGS=-L/usr/local/lib
        fi
    else
        cd ./$OBJ_DIR
    fi

#    pkill oai_epc
#    pkill tshark

    if [ -f Makefile ]; then
        echo_success "Compiling..."
        make -j $NUM_CPU
        if [ $? -ne 0 ]; then
            echo_error "Build failed, exiting"
            return 1
        else 
            cp -f ./OAI_EPC/oai_epc  $OPENAIR_TARGETS/bin
        fi
    else
        echo_error "Configure failed, exiting"
        return 1
    fi
    
    cd $OPENAIRCN_DIR/GTPV1-U/GTPUAH;
    make
    if [ $? -ne 0 ]; then
        echo_error "Build GTPUAH module failed, exiting"
        return 1
    else 
        cp -fv ./Bin/libxt_*.so /lib/xtables
        cp -fv ./Bin/*.ko $OPENAIR_TARGETS/bin
    fi
    
    cd $OPENAIRCN_DIR/GTPV1-U/GTPURH;
    make
    if [ $? -ne 0 ]; then
        echo_error "Build GTPURH module failed, exiting"
        return 1
    else 
        cp -fv ./Bin/libxt_*.so /lib/xtables
        cp -fv ./Bin/*.ko $OPENAIR_TARGETS/bin
    fi
    return 0
}

compile_exmimo2_driver() {
    cd $OPENAIR_TARGETS/ARCH/EXMIMO/DRIVER/eurecom && make clean && make   || exit 1
    cd $OPENAIR_TARGETS/ARCH/EXMIMO/USERSPACE/OAI_FW_INIT && make clean && make   || exit 1
    # TO DO CHECKS...
}


compile_ltesoftmodem() {
    cd $OPENAIR_TARGETS/RT/USER
    if [ -f Makefile ];  then
        echo "LTE softmodem compiling directives: $SOFTMODEM_DIRECTIVES"
        if [ $OAI_CLEAN -ne 0 ]; then
            echo "Cleaning LTE softmodem"
            make cleanall > /dev/null 2>&1
        fi
        make -j $NUM_CPU $SOFTMODEM_DIRECTIVES
        if [ $? -ne 0 ]; then
            # to locate easily compilation error in log file
            make  $SOFTMODEM_DIRECTIVES
        fi 
        if [ $? -ne 0 ]; then
            if [ ! -f ./lte-softmodem ]; then 
                echo_error "Build lte-softmodem failed, returning"
                return 1
            else 
                cp -f ./lte-softmodem  $OPENAIR_TARGETS/bin
                return 0
            fi 
        else
            cp -f ./lte-softmodem  $OPENAIR_TARGETS/bin
            return 0
        fi
    else
        echo_error "make file for oai softmodem not found, returning"
        return 1
    fi
}

compile_oaisim() {
    cd $OPENAIR_TARGETS/SIMU/USER
    if [ -f Makefile ]; then
        echo "Compiling for oaisim  target ($OAISIM_DIRECTIVES)"
        make cleanall > /dev/null
        make -j $NUM_CPU $OAISIM_DIRECTIVES 
        if [ $? -ne 0 ]; then
            echo_error "Build oaisim failed, returning"
            return 1
        else 
            cp -f ./oaisim $OPENAIR_TARGETS/bin
            return 0
        fi
    else
        echo_error "Makefile not found for oaisim target, returning"
        return 1
    fi
}

compile_unisim() {
    cd $OPENAIR1_DIR/SIMULATION/LTE_PHY
    if [ -f Makefile ]; then
        echo "Compiling for UNISIM target ..."
        make cleanall
        make  -j $NUM_CPU all 
        if [ $? -ne 0 ]; then
            echo_error "Build unisim failed, returning"
            return 1
        else 
            cp -f ./dlsim     $OPENAIR_TARGETS/bin
            cp -f ./ulsim     $OPENAIR_TARGETS/bin
            cp -f ./pucchsim  $OPENAIR_TARGETS/bin
            cp -f ./prachsim  $OPENAIR_TARGETS/bin
            cp -f ./pdcchsim  $OPENAIR_TARGETS/bin
            cp -f ./pbchsim   $OPENAIR_TARGETS/bin
            cp -f ./mbmssim   $OPENAIR_TARGETS/bin
            return 0
        fi
    else
        echo_error "Configure failed, exiting"
        return 1
    fi
}
################################################
# 1. check if the executable functions exist
###############################################

check_for_ltesoftmodem_executable() {
    if [ ! -f $OPENAIR_TARGETS/RT/USER/lte-softmodem ];   then
        echo_error "Cannot find lte-softmodem executable object in directory $OPENAIR_TARGETS/RT/USER"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

check_for_epc_executable() {
    if [ ! -f $OPENAIRCN_DIR/objs/OAI_EPC/oai_epc ]; then
        echo_error "Cannot find oai_epc executable object in directory $OPENAIRCN_DIR/objs/OAI_EPC/"
        echo_error "Please make sure you have compiled OAI EPC with --enable-standalone-epc option"
    fi
}

check_for_hss_executable() {
    if [ ! -f $OPENAIRCN_DIR/OPENAIRHSS/objs/openair-hss ]; then
        echo_error "Cannot find openair-hss executable object in directory $OPENAIRCN_DIR/OPENAIRHSS/objs/"
        echo_error "Please make sure you have compiled OAI HSS"
    fi
}

check_for_sgw_executable() {
    if [ ! -f $OPENAIRCN_DIR/objs/OAI_SGW/oai_sgw ]; then
        echo_error "Cannot find oai_sgw executable object in directory $OPENAIR3_DIR/OPENAIRMME/objs/OAI_SGW/"
        echo_fatal "Please make sure you have compiled OAI EPC without --enable-standalone-epc option"
    fi
}

check_for_oaisim_executable() {
    if [ ! -f $OPENAIR_TARGETS/SIMU/USER/oaisim ]; then
        echo_error "Cannot find oaisim executable object in directory $OPENAIR_TARGETS/SIMU/USER"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

check_for_dlsim_executable() {
    if [ ! -f $OPENAIR1_DIR/SIMULATION/LTE_PHY/dlsim ];  then
        echo_error "Cannot find dlsim executable object in directory $OPENAIR1_DIR/SIMULATION/LTE_PHY"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

check_for_ulsim_executable() {
    if [ ! -f $OPENAIR1_DIR/SIMULATION/LTE_PHY/ulsim ]; then
        echo_error "Cannot find ulsim executable object in directory $OPENAIR1_DIR/SIMULATION/LTE_PHY"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

check_for_pucchsim_executable() {
    if [ ! -f $OPENAIR1_DIR/SIMULATION/LTE_PHY/pucchsim ]; then
        echo_error "Cannot find pucchsim executable object in directory $OPENAIR1_DIR/SIMULATION/LTE_PHY"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

check_for_prachsim_executable() {
    if [ ! -f $OPENAIR1_DIR/SIMULATION/LTE_PHY/prachsim ]; then
        echo_error "Cannot find prachsim executable object in directory $OPENAIR1_DIR/SIMULATION/LTE_PHY"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

check_for_pdcchsim_executable() {
    if [ ! -f $OPENAIR1_DIR/SIMULATION/LTE_PHY/pdcchsim ]; then
        echo_error "Cannot find pdcchsim executable object in directory $OPENAIR1_DIR/SIMULATION/LTE_PHY"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

check_for_pbchsim_executable() {
    if [ ! -f $OPENAIR1_DIR/SIMULATION/LTE_PHY/pbchsim ]; then
        echo_error "Cannot find pbchsim executable object in directory $OPENAIR1_DIR/SIMULATION/LTE_PHY"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

check_for_mbmssim_executable() {
    if [ ! -f $OPENAIR1_DIR/SIMULATION/LTE_PHY/mbmssim ]; then
        echo_error "Cannot find mbmssim executable object in directory $OPENAIR1_DIR/SIMULATION/LTE_PHY"
        echo_error "Check the compilation logs in bin/install_log.txt"
    fi
}

################################################
# 1. check if the executable functions exist
###############################################

install_ltesoftmodem() {
    # RT
    if [ $1 = "RTAI" ]; then 
	if [ ! -f /tmp/init_rt_done.tmp ]; then
            echo_info "  8.1 Insert RTAI modules"
            $SUDO$ insmod /usr/realtime/modules/rtai_hal.ko     > /dev/null 2>&1
            $SUDO$ insmod /usr/realtime/modules/rtai_sched.ko   > /dev/null 2>&1
            $SUDO$ insmod /usr/realtime/modules/rtai_sem.ko     > /dev/null 2>&1
            $SUDO$ insmod /usr/realtime/modules/rtai_fifos.ko   > /dev/null 2>&1
            $SUDO$ insmod /usr/realtime/modules/rtai_mbx.ko     > /dev/null 2>&1
            $SUDO$ touch /tmp/init_rt_done.tmp
            $SUDO$ chmod 666 /tmp/init_rt_done.tmp
        else
            echo_warning "  8.1 RTAI modules already inserted"
        fi
    fi
    #HW
    if [ $2 = "EXMIMO" ]; then 
	echo_info "  8.2 [EXMIMO] creating RTAI fifos"
	for i in `seq 0 64`; do 
	    have_rtfX=`ls /dev/ |grep -c rtf$i`;
	    if [ "$have_rtfX" -eq 0 ] ; then 
		$SUDO mknod -m 666 /dev/rtf$i c 150 $i; 
	    fi;
	done
	echo_info "  8.3 [EXMIMO] Build lte-softmodemdrivers"
	cd $OPENAIR_TARGETS/ARCH/EXMIMO/DRIVER/eurecom && make clean && make  # || exit 1
	cd $OPENAIR_TARGETS/ARCH/EXMIMO/USERSPACE/OAI_FW_INIT && make clean && make  # || exit 1
	
	echo_info "  8.4 [EXMIMO] Setup RF card"
	cd $OPENAIR_TARGETS/RT/USER
	. ./init_exmimo2.sh
    else 
	if [ $2 = "USRP" ]; then
	    echo_info "  8.2 [USRP] "
	fi

    fi
    
    # ENB_S1
    if [ $3 = 0 ]; then 
	cd $OPENAIR2_DIR && make clean && make nasmesh_netlink.ko  #|| exit 1
	cd $OPENAIR2_DIR/NAS/DRIVER/MESH/RB_TOOL && make clean && make  # || exit 1
    fi
    
}

install_oaisim() {
   if [ $1 = 0 ]; then 
	cd $OPENAIR2_DIR && make clean && make nasmesh_netlink.ko  #|| exit 1
	cd $OPENAIR2_DIR/NAS/DRIVER/MESH/RB_TOOL && make clean && make  # || exit 1
   fi 
   
}

##################################
# create HSS DB
################################

# arg 1 is mysql user      (root)
# arg 2 is mysql password  (linux)
create_hss_database(){
    EXPECTED_ARGS=2
    E_BADARGS=65
    MYSQL=`which mysql`
    rv=0
    if [ $# -ne $EXPECTED_ARGS ]
    then
        echo_fatal "Usage: $0 dbuser dbpass"
	rv=1
    fi

    set_openair_env
    
    Q1="CREATE DATABASE IF NOT EXISTS ${BTICK}oai_db${BTICK};"
    SQL="${Q1}"
    $MYSQL -u $1 --password=$2 -e "$SQL"
    if [ $? -ne 0 ]; then
       echo_error "oai_db creation failed"
       rv=1
    else
       echo_success "oai_db creation succeeded"
    fi
    
    $MYSQL -u $1 --password=$2 oai_db < $OPENAIRCN_DIR/OPENAIRHSS/db/oai_db.sql
    if [ $? -ne 0 ]; then
       echo_error "oai_db tables creation failed"
       rv=1
    else
       echo_success "oai_db tables creation succeeded"
    fi
    
    Q1="GRANT ALL PRIVILEGES ON *.* TO 'hssadmin'@'%' IDENTIFIED BY 'admin' WITH GRANT OPTION;"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}"
    $MYSQL -u $1 --password=$2 -e "$SQL"
    if [ $? -ne 0 ]; then
       echo_error "hssadmin permissions failed"
       rv=1
    else
       echo_success "hssadmin permissions succeeded"
    fi
    return rv
}

################################
# set_openair_env
###############################
set_openair_env(){

    fullpath=`readlink -f $BASH_SOURCE`
    [ -f "/.$fullpath" ] || fullpath=`readlink -f $PWD/$fullpath`
    openair_path=${fullpath%/targets/*}
    openair_path=${openair_path%/openair-cn/*}
    openair_path=${openair_path%/openair[123]/*}

    export OPENAIR_DIR=$openair_path
    export OPENAIR_HOME=$openair_path
    export OPENAIR1_DIR=$openair_path/openair1
    export OPENAIR2_DIR=$openair_path/openair2
    export OPENAIR3_DIR=$openair_path/openair3
    export OPENAIRCN_DIR=$openair_path/openair-cn
    export OPENAIR_TARGETS=$openair_path/targets

}

########################################
### print help
######################################

print_help(){
    echo_success "Name : build_oai  - install and build OAI"
    echo_success "Usage: build_oai.bash -a -b -c -d -e RTAI -m -r REL8 -s -t OAISIM -w EXMIMO -x"
    echo_success "-a | --doxygen                          : Enable doxygen for documentation (default disabled)"
    echo_success "-b | --disable-s1                       : Disable S1 interface for eNB (default enabled)"
    echo_success "-c | --clean                            : Enable clean OAI build (default disabled)"
    echo_success "-C | --config-file                      : Set the config file local path"
    echo_success "-d | --debug                            : Enable debug mode (default disabled)"
    echo_success "-D | --disable-check-installed-software : Disable the checking of installed software (default is check)"
    echo_success "-e | --realtime                         : Set realtime mode: RTAI, NONE (default NONE)"
    echo_success "-g | --run-with-gdb                     : Run the executable built by this script with gdb"
    echo_success "-K | --itti-dump-file                   : Set the execution events trace file"
    echo_success "-l | --build-target                     : Set the LTE build target: ENB,EPC,HSS,NONE (default ENB)"
    echo_success "-m | --build-from-makefile              : Enable build from the makefile (default disabled)"
    echo_success "-r | --3gpp-release                     : Set the release: REL8, REL10 (default REL8)"
    echo_success "-R | --run                              : Run the executable built by this script"
    echo_success "-s | --check                            : Enable OAI testing and sanity check (default disabled)"
    echo_success "-t | --enb-build-target                 : Set the eNB build target: ALL, SOFTMODEM,OAISIM,UNISIM (default ALL)"
    echo_success "-V | --vcd                              : Log vcd events"
    echo_success "-w | --hardware                         : Set the hardware platform: EXMIMO, USRP (also installs UHD driver), ETHERNET, NONE, (default EXMIMO)"
    echo_success "-x | --xforms                           : Enable xforms (default disabled)"
    echo_success "-z | --defaults                         : Set the default build options"
}
###############################
## echo and  family 
###############################
black='\E[30m'
red='\E[31m'
green='\E[32m'
yellow='\E[33m'
blue='\E[34m'
magenta='\E[35m'
cyan='\E[36m'
white='\E[37m'
reset_color='\E[00m'


cecho()   # Color-echo
# arg1 = message
# arg2 = color
{
    local default_msg="No Message."
    message=${1:-$default_msg}
    color=${2:-$green}
    if [ $BUILD_FROM_MAKEFILE = 0 ]; then 
	echo -e -n "$color$message$reset_color"
	echo
    else 
	echo "$message"
    fi
    return
}

echo_error() {
    local my_string=""
    until [ -z "$1" ]
    do
        my_string="$my_string$1"
        shift
        done
        cecho "$my_string" $red
}

echo_fatal() {
    local my_string=""
    until [ -z "$1" ]
    do
        my_string="$my_string$1"
        shift
        done
        echo_error "$my_string"
    exit -1
}

echo_warning() {
    local my_string=""
    until [ -z "$1" ]
    do
        my_string="$my_string$1"
        shift
    done
    cecho "$my_string" $yellow
}

echo_success() {
    local my_string=""
    until [ -z "$1" ]
    do
        my_string="$my_string$1"
        shift
    done
    cecho "$my_string" $green
}
echo_info() {
    local my_string=""
    until [ -z "$1" ]
    do
        my_string="$my_string$1"
        shift
    done
    cecho "$my_string" $blue
}

bash_exec() {
    output=$($1 2>&1)
    result=$?
    if [ $result -eq 0 ]; then
        echo_success "$1"
    else
        echo_error "$1: $output"
    fi
}


wait_process_started () {
    if  [ -z "$1" ]; then
        echo_error "WAITING FOR PROCESS START: NO PROCESS"
        return 1
    fi
    ps -C $1 > /dev/null 2>&1
    while [ $? -ne 0 ]; do
        echo_warning "WAITING FOR $1 START"
        sleep 2
        ps -C $1 > /dev/null 2>&1
    done
    echo_success "PROCESS $1 STARTED"
    return 0
}

is_process_started () {
    if  [ -z "$1" ]; then
        echo_error "WAITING FOR PROCESS START: NO PROCESS"
        return 1
    fi
    ps -C $1 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo_success "PROCESS $1 NOT STARTED"
        return 1
    fi
    echo_success "PROCESS $1 STARTED"
    return 0
}

assert() {
    # If condition false
    # exit from script with error message
    E_PARAM_ERR=98
    E_PARAM_FAILED=99

    if [ -z "$2" ] ; then # Not enought parameters passed.
        return $E_PARAM_ERR
    fi
    
    lineno=$2
    if [ ! $1 ]; then
        echo_error "Assertion failed:  \"$1\""
        echo_fatal "File \"$0\", line $lineno"
    fi
}
