#! /bin/bash
export LANG=C
export LC_ALL=C

function copydsc () {
    local DSCFILE="$1"
    local TARGET="$2"
    for FILE in \
      "$DSCFILE" \
      $(echo "$DSCFILE" | sed 's/^\(.*\)\.dsc$/\1/' ).diff.gz \
      $(echo "$DSCFILE" | sed 's/^\(.*\)\.dsc$/\1/').tar.gz \
      $(echo "$DSCFILE" | sed 's/\(.*\)-[^-.]*\.dsc$/\1/').orig.tar.gz ; do
        cp "$FILE" "$TARGET" ;
    done

}

function checkbuilddep () {
    for INSTALLPKG in $($CHROOTEXEC bin/sh -c "(cd tmp/buildd/*/; dpkg-checkbuilddeps)" 2>&1 |grep "^dpkg-checkbuilddeps: Unmet build dependencies: " | sed 's/^[^:]*:[^:]*: \(.*\)$/\1/' | awk 'BEGIN{RS=", "} /^([^([]*)/{print $1}'); do
	echo " -> Installing $INSTALLPKG"
	$CHROOTEXEC usr/bin/apt-get -y install "$INSTALLPKG"
    done;
    for REMOVEPKG in $($CHROOTEXEC bin/sh -c "(cd tmp/buildd/*/; dpkg-checkbuilddeps)" 2>&1 |grep "^dpkg-checkbuilddeps: Build conflicts: " | sed 's/^[^:]*:[^:]*: \(.*\)$/\1/' | awk 'BEGIN{RS=", "} /^([^([]*)/{print $1}'); do
	echo " -> Removing $REMOVEPKG"
	$CHROOTEXEC usr/bin/apt-get -y remove "$REMOVEPKG"
    done;
}


. /etc/pbuilderrc
. /usr/lib/pbuilder/pbuilder-checkparams
PACKAGENAME="$1"
CHROOTEXEC="chroot $BUILDPLACE "

echo cleaning the build env
rm -rf "$BUILDPLACE"

echo building the build env
mkdir -p "$BUILDPLACE"
(
 cd "$BUILDPLACE"
 tar xfzp "$BASETGZ"
 mkdir -p "$BUILDPLACE/tmp/buildd"
)
echo Copying source file
copydsc "$PACKAGENAME" "$BUILDPLACE/tmp/buildd"
echo Extracting source
$CHROOTEXEC /bin/bash -c "( cd tmp/buildd; /usr/bin/dpkg-source -x $(basename $PACKAGENAME) )"
echo Installing the build-deps
checkbuilddep
echo Building the package
$CHROOTEXEC /bin/sh -c "(cd tmp/buildd/*/; dpkg-buildpackage)"

