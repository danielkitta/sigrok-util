#!/bin/sh
set -e
scriptdir=$(dirname "$0")
scriptname=$(basename "$0")

# Settings passed via command-line options or auto-detected.
# These variables may be referenced by an environment script.
BASE=
HOST=

# Default configuration. These variables may be overridden
# by an environment script named $HOST.env, or default.env
# if no host platform was specified.
PREFIX=
LIB_CONFIGURE_ARGS=
CMAKE_TOOLCHAIN_FILE=
MAKE=make
PARALLEL=
NSIS_DESTDIR=
NSIS_REMOVE_OLD=no
DEFAULT_MODULES='libserialport libsigrok libsigrokdecode'\
' sigrok-firmware sigrok-firmware-fx2lafw sigrok-dumps sigrok-test'\
' sigrok-cli pulseview'

# Internal variables.
buildlist=
skiplist=
makejobs=
optflags=

print_help() {
    cat <<EOF
Usage: $scriptname [OPTION]... [MODULE]...

Build and install a set of sigrok modules.

     --base=DIRECTORY   set the base DIRECTORY of the module sources
 -s, --skip=MODULE      exclude MODULE from the build
 -h, --host=HOST        set HOST platform to build for
     --prefix=PREFIX    set module installation PREFIX

 -a, --autogen          force bootstrap of module (implies --reconf)
 -c, --clean            make clean before compiling a module
 -r, --reconf           reconfigure each module before building
 -v, --verbose          enable verbose build output
 -j, --jobs=N           allow N parallel make jobs

     --dry-run          do not build anything, only print what would happen
     --dump-env         show the environment for the selected host platform

 -?, --help             output this help

If no MODULE is specified, a default set of modules will be built.
EOF
}

need_arg() {
    if [ -z "$arg" ]; then
        echo "$scriptname: argument expected after '$opt' (try --help)" >&2
        exit 1
    fi
    optskip=$argskip
}

# Parse command-line flags.
while [ "$#" -gt 0 ]; do
    optskip=1
    case $1 in
        -|--) shift; break;;
        -*=*) opt=${1%%=*} arg=${1#*=} argskip=1;;
        -*)   opt=$1 arg=$2 argskip=2;;
        *)    break;;
    esac
    case $opt in
        --autogen)
            optflags=${optflags}a
            ;;
        --base)
            need_arg
            BASE=$arg
            ;;
        --clean)
            optflags=${optflags}c
            ;;
        --dry-run)
            optflags=${optflags}d
            ;;
        --dump-env)
            optflags=${optflags}e
            ;;
        -h|--host)
            need_arg
            HOST=$arg
            ;;
        -j|--jobs)
            need_arg
            makejobs=$arg
            ;;
        -j[0-9]*)
            makejobs=${opt#-j}
            ;;
        --prefix)
            need_arg
            PREFIX=$arg
            ;;
        --reconf)
            optflags=${optflags}r
            ;;
        -s|--skip)
            need_arg
            skiplist="$skiplist $arg"
            ;;
        --verbose)
            optflags=${optflags}v
            ;;
        '-?'|--help)
            print_help
            exit 0
            ;;
        -*[!acrv]*)
            echo "$scriptname: unrecognized option '$opt' (try --help)" >&2
            exit 1
            ;;
        *)
            optflags=$optflags${opt#-}
            ;;
    esac
    shift "$optskip"
done

buildlist=$*

# Try to locate the base source directory of the sigrok modules.
# Verify the location by checking for a source file of libsigrok.
srcfile=libsigrok/src/libsigrok-internal.h

if [ -n "$BASE" ]; then
    BASE=$(cd "$BASE" >/dev/null && pwd)
    if [ ! -f "$BASE/$srcfile" ]; then
        echo "$scriptname: cannot find sigrok sources in '$BASE'" >&2
        exit 1
    fi
else
    BASE=$(cd "$scriptdir" >/dev/null && pwd)
    # Search parent directories.
    while [ ! -f "$BASE/$srcfile" ]; do
        BASE=${BASE%[\\/]*}
        case $BASE in
            *[\\/]*) :;;
            *)  echo "$scriptname: cannot find sigrok sources in '$scriptdir' or its parents" >&2
                exit 1;;
        esac
    done
fi

# Option-dependent default for BUILD_BASE. May be overridden
# by an environment script.
BUILD_BASE=$BASE/build${HOST:+"-$HOST"}

# Look for a build environment script.
envscript=${HOST:-default}.env
envdir=
for dir in "$BASE" "$scriptdir"
do
    if [ -f "$dir/$envscript" ]; then
        envdir=$dir
        break
    fi
done
# Now source the environment script if found.
if [ -n "$envdir" ]; then
    echo "$scriptname: environment script '$envdir/$envscript'"
    . "$envdir/$envscript"
elif [ -n "$HOST" ]; then
    echo "$scriptname: WARNING: missing environment script '$envscript'" >&2
else
    echo "$scriptname: no environment script, using built-in defaults"
fi

if [ -z "$buildlist" ]; then
    # Use default module list from the environment.
    buildlist=$DEFAULT_MODULES
fi
if [ -n "$makejobs" ]; then
    # Command-line option overrides environment setting.
    PARALLEL=$makejobs
fi

# Dump environment if requested.
case $optflags in
    *e*) cat <<EOF
BASE="$BASE"
BUILD_BASE="$BUILD_BASE"
HOST="$HOST"
PREFIX="$PREFIX"
CMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE"
LIB_CONFIGURE_ARGS="$LIB_CONFIGURE_ARGS"
CONFIGURE_ARGS_libusb="$CONFIGURE_ARGS_libusb"
CONFIGURE_ARGS_libserialport="$CONFIGURE_ARGS_libserialport"
CONFIGURE_ARGS_libsigrok="$CONFIGURE_ARGS_libsigrok"
CONFIGURE_ARGS_libsigrokdecode="$CONFIGURE_ARGS_libsigrokdecode"
CONFIGURE_ARGS_sigrok_firmware="$CONFIGURE_ARGS_sigrok_firmware"
CONFIGURE_ARGS_sigrok_firmware_fx2lafw="$CONFIGURE_ARGS_sigrok_firmware_fx2lafw"
CONFIGURE_ARGS_sigrok_test="$CONFIGURE_ARGS_sigrok_test"
CONFIGURE_ARGS_sigrok_cli="$CONFIGURE_ARGS_sigrok_cli"
CONFIGURE_ARGS_pulseview="$CONFIGURE_ARGS_pulseview"
MAKE_ARGS_libusb="$MAKE_ARGS_libusb"
MAKE_ARGS_libserialport="$MAKE_ARGS_libserialport"
MAKE_ARGS_libsigrok="$MAKE_ARGS_libsigrok"
MAKE_ARGS_libsigrokdecode="$MAKE_ARGS_libsigrokdecode"
MAKE_ARGS_sigrok_firmware="$MAKE_ARGS_sigrok_firmware"
MAKE_ARGS_sigrok_firmware_fx2lafw="$MAKE_ARGS_sigrok_firmware_fx2lafw"
MAKE_ARGS_sigrok_dumps="$MAKE_ARGS_sigrok_dumps"
MAKE_ARGS_sigrok_test="$MAKE_ARGS_sigrok_test"
MAKE_ARGS_sigrok_cli="$MAKE_ARGS_sigrok_cli"
MAKE_ARGS_pulseview="$MAKE_ARGS_pulseview"
MAKE_ARGS_sigrok_installer="$MAKE_ARGS_sigrok_installer"
MAKE="$MAKE"
PARALLEL="$PARALLEL"
NSIS_DESTDIR="$NSIS_DESTDIR"
NSIS_REMOVE_OLD="$NSIS_REMOVE_OLD"
DEFAULT_MODULES="$DEFAULT_MODULES"
EOF
    exit 0;;
esac

echo "$scriptname: source base   : $BASE"
echo "$scriptname: build base    : $BUILD_BASE"
echo "$scriptname: host platform : ${HOST:-default}"
echo "$scriptname: install prefix: $PREFIX"

test_flag() {
    case $optflags in
        *"$1"*) return 0;;
        *)      return 1;;
    esac
}

test_skip() {
    case " $buildlist " in
        *" $1 "*) :;;
        *) return 0;;
    esac
    case " $skiplist " in
        *" $1 "*) return 0;;
        *) return 1;;
    esac
}

build_intro() {
    if test_skip "$module"; then
        echo "$scriptname: Skipping $module."
        return 1
    fi
    branch=$(git -C "$srcdir" rev-parse --abbrev-ref HEAD 2>/dev/null)

    echo "$scriptname: Building $module${branch:+ (branch $branch)}..."
    return 0
}

# Print and execute command line.
run() {
    echo "\$ $*"
    case $optflags in
        *d*) :;; # dry run
        *) "$@" || exit 1;;
    esac
}

# Run make and make install.
run_make() {
    insttarget=$1
    von=$2
    voff=$3

    echo "$scriptname: Compiling $module..."

    case $optflags in
        *c*) run $MAKE clean;;
    esac
    eval "set X $makeargs"
    shift
    case $optflags in
        *v*) run $MAKE ${PARALLEL:+"-j$PARALLEL"} "$@" ${von:+"$von"};;
        *)   run $MAKE ${PARALLEL:+"-j$PARALLEL"} "$@" ${voff:+"$voff"};;
    esac
    run $MAKE "$insttarget"
}

# Build a module using Autoconf/Automake.
build_autotools() {
    module=$1
    confargs=$2
    makeargs=$3
    srcdir=$BASE/$module
    builddir=$BUILD_BASE/$module

    build_intro || return 0

    if test_flag a || [ ! -f "$srcdir/configure" ]; then
        echo "$scriptname: Bootstrapping $module..."
        cd "$srcdir"
        if [ -f bootstrap.sh ]; then
            run ./bootstrap.sh
        elif [ -f autogen.sh ]; then
            run ./autogen.sh
        else
            run autoreconf --force --install --verbose
        fi
        cd - >/dev/null
    fi

    mkdir -p "$builddir"
    cd "$builddir"

    # If already configured, let make figure out if we need to reconfigure.
    if test_flag a || test_flag r || [ ! -f Makefile ]; then
        echo "$scriptname: Configuring $module..."
        eval "set X $confargs"
        shift
        run "$srcdir/configure" ${HOST:+"--host=$HOST"} \
            ${PREFIX:+"--prefix=$PREFIX"} "$@"
    fi

    run_make install V=1 V=0

    cd - >/dev/null
}

# Build a module using CMake.
build_cmake() {
    module=$1
    confargs=$2
    makeargs=$3
    srcdir=$BASE/$module
    builddir=$BUILD_BASE/$module

    build_intro || return 0

    mkdir -p "$builddir"
    cd "$builddir"

    # Interpret --autogen as request to reset the configuration.
    if test_flag a && [ -f CMakeCache.txt ]; then
        run rm -f CMakeCache.txt
    fi

    if test_flag a || test_flag r || [ ! -f Makefile ]; then
        echo "$scriptname: Configuring $module..."
        eval "set X $confargs"
        shift
        run cmake \
            ${CMAKE_TOOLCHAIN_FILE:+"-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"} \
            ${PREFIX:+"-DCMAKE_INSTALL_PREFIX:PATH=$PREFIX"} "$@" "$srcdir"
    fi

    run_make install VERBOSE=1

    cd - >/dev/null
}

# Install sigrok-dumps.
build_sigrok_dumps() {
    makeargs=$1
    module=sigrok-dumps
    srcdir=$BASE/$module

    build_intro || return 0

    run $MAKE -C "$srcdir" "DESTDIR=$PREFIX/share/$module" $makeargs install
}

# Build Windows installer.
build_sigrok_installer() {
    makeargs=$1
    module=sigrok-installer
    srcdir=$BASE/sigrok-util/cross-compile/mingw
    builddir=$BUILD_BASE/sigrok-util/cross-compile/mingw

    build_intro || return 0

    mkdir -p "$builddir"
    run rm -f "$builddir"/sigrok-*-installer.exe

    case $optflags in
        *v*) vlevel=4;;
        *)   vlevel=2;;
    esac
    run makensis "-V$vlevel" "-DPREFIX=$PREFIX" "-DOUTDIR=$builddir" \
        $makeargs "$srcdir/sigrok.nsi"

    if [ -n "$NSIS_DESTDIR" ]; then
        run mkdir -p "$NSIS_DESTDIR"
        if [ "x$NSIS_REMOVE_OLD" = xyes ]; then
            run rm -f "$NSIS_DESTDIR"/sigrok-*-installer.exe
        fi
        run install -m 0755 -t "$NSIS_DESTDIR" \
            "$builddir"/sigrok-*-installer.exe
    fi
}

# Build all enabled modules in order.

mkdir -p "$BUILD_BASE"

build_autotools libusb \
    "$LIB_CONFIGURE_ARGS $CONFIGURE_ARGS_libusb" \
    "$MAKE_ARGS_libusb"

build_autotools libserialport \
    "$LIB_CONFIGURE_ARGS $CONFIGURE_ARGS_libserialport" \
    "$MAKE_ARGS_libserialport"

build_autotools libsigrok \
    "$LIB_CONFIGURE_ARGS $CONFIGURE_ARGS_libsigrok" \
    "$MAKE_ARGS_libsigrok"

build_autotools libsigrokdecode \
    "$LIB_CONFIGURE_ARGS $CONFIGURE_ARGS_libsigrokdecode" \
    "$MAKE_ARGS_libsigrokdecode"

build_autotools sigrok-firmware \
    "$CONFIGURE_ARGS_sigrok_firmware" \
    "$MAKE_ARGS_sigrok_firmware"

build_autotools sigrok-firmware-fx2lafw \
    "$CONFIGURE_ARGS_sigrok_firmware_fx2lafw" \
    "$MAKE_ARGS_sigrok_firmware_fx2lafw"

build_sigrok_dumps "$MAKE_ARGS_sigrok_dumps"

build_autotools sigrok-test \
    "$CONFIGURE_ARGS_sigrok_test" \
    "$MAKE_ARGS_sigrok_test"

build_autotools sigrok-cli \
    "$CONFIGURE_ARGS_sigrok_cli" \
    "$MAKE_ARGS_sigrok_cli"

build_cmake pulseview \
    "$CONFIGURE_ARGS_pulseview" \
    "$MAKE_ARGS_pulseview"

build_sigrok_installer "$MAKE_ARGS_sigrok_installer"

exit 0
