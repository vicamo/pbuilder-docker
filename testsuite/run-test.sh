#!/bin/sh
# This is a testsuite.
# estimated run-time on my PC; 16 minutes.

PBUILDER=/usr/sbin/pbuilder

RESULTFILE="run-test.log"
: > ${RESULTFILE}
RESULTFILE=$(readlink -f ${RESULTFILE})

log_success () {
    CODE=$?
    if [ $CODE = 0 ]; then
	echo "[OK]   $1" >> ${RESULTFILE}
    else
	echo "[FAIL] $1" >> ${RESULTFILE}
    fi
}



mirror=http://ring.asahi-net.or.jp/archives/linux/debian/debian
logdir=$(readlink -f normal/)

testdir=$(TMPDIR=$(pwd) mktemp -d)
testimage=$testdir/testimage
testbuild=$testdir/dir1
testbuild2=$testdir/dir2

if [ -x "${PBUILDER}" ]; then
    for distribution in sid sarge etch; do
	sudo ${PBUILDER} create --mirror $mirror --distribution "${distribution}" --basetgz ${testimage} --logfile ${logdir}/pbuilder-create-${distribution}.log 
# --hookdir /usr/share/doc/pbuilder/examples/libc6workaround
	log_success create-${distribution}

	for PKG in dsh; do 
	    ( 
		mkdir ${testbuild}
		cd ${testbuild}
		apt-get source -d ${PKG}
	    )
	    sudo ${PBUILDER} build --debemail "Junichi Uekawa <dancer@debian.org>" --basetgz ${testimage} --buildplace ${testbuild}/ --logfile ${logdir}/pbuilder-build-${PKG}-${distribution}.log ${testbuild}/${PKG}*.dsc
	    log_success build-${distribution}-${PKG}

	    (
		mkdir ${testbuild2}
		cd ${testbuild2}
		apt-get source ${PKG}
		cd ${PKG}-*
		pdebuild --logfile ${logdir}/pdebuild-normal-${distribution}.log -- --basetgz ${testimage} --buildplace ${testbuild2}
		log_success pdebuild-${distribution}-${PKG}

		pdebuild --use-pdebuild-internal --logfile ${logdir}/pdebuild-internal-${distribution}.log -- --basetgz ${testimage} --buildplace ${testbuild2}
		log_success pdebuild-internal-${distribution}-${PKG}
	    )
	done
	sudo ${PBUILDER} execute --basetgz ${testimage} --logfile ${logdir}/pbuilder-execute-${distribution}.log ../examples/execute_paramtest.sh test1 test2 test3

	# upgrading testing.
	case $distribution in 
	    sarge)
		sudo ${PBUILDER} update --basetgz ${testimage} --distribution etch --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-etch.log 
		log_success update-${distribution}-etch.log
		sudo ${PBUILDER} update --basetgz ${testimage} --distribution sid --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-etch-sid.log 
		log_success update-${distribution}-etch-sid.log
		sudo ${PBUILDER} update --basetgz ${testimage} --distribution experimental --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-etch-sid-experimental.log 
		log_success update-${distribution}-etch-sid-experimental.log
		;;
	    etch)
		sudo ${PBUILDER} update --basetgz ${testimage} --distribution sid --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-sid.log 
		log_success update-${distribution}-sid.log
		sudo ${PBUILDER} update --basetgz ${testimage} --distribution experimental --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-sid-experimental.log 
		log_success update-${distribution}-sid-experimental.log
		;;
	esac

	sudo rm -rf ${testbuild} ${testbuild2} ${testimage}
    done
fi

rm -r ${testdir}
