#!/bin/bash
#
# This script installs the required build-time dependencies
# and builds AppImage
#


STRIP="strip"
INSTALL_DEPENDENCIES=0
STATIC_BUILD=1
JOBS=${JOBS:-1}

while [ $1 ]; do
  case $1 in
    '--debug' | '-d' )
      STRIP="true"
      ;;
    '--no-dependencies' | '-n' )
      INSTALL_DEPENDENCIES=0
      ;;
    '--use-shared-libs' | '-s' )
      STATIC_BUILD=0
      ;;
    '--clean' | '-c' )
      rm -rf build
      git clean -df
      rm -rf squashfuse/* squashfuse/.git
      rm -rf squashfs-tools/* squashfs-tools/.git
      exit
      ;;
    '--help' | '-h' )
      echo 'Usage: ./build.sh [OPTIONS]'
      echo
      echo 'OPTIONS:'
      echo '  -h, --help: Show this help screen'
      echo '  -d, --debug: Build with debug info.'
      echo '  -n, --no-dependencies: Do not try to install distro specific build dependencies.'
      echo '  -s, --use-shared-libs: Use distro provided shared versions of inotify-tools and openssl.'
      echo '  -c, --clean: Clean all artifacts generated by the build.'
      exit
      ;;
  esac

  shift
done

echo $KEY | md5sum

set -e
set -x

HERE="$(dirname "$(readlink -f "${0}")")"
cd "$HERE"

# Install dependencies if enabled
if [ $INSTALL_DEPENDENCIES -eq 1 ]; then
  . ./install-build-deps.sh
fi

# Fetch git submodules
git submodule update --init --recursive

# Clean up from previous run
[ -d build/ ] && rm -rf build/

# Build AppImage
mkdir build
cd build

cmake ..
make -j8

xxd runtime | head -n 1
mv runtime runtime_with_magic


cd ..

## Lib AppImage optional

mkdir -p libappimage/build
pushd libappimage/build
cmake .. && make all && ctest 
popd

# Strip and check size and dependencies

rm build/*.o
$STRIP build/AppRun build/appimaged build/appimagetool build/digest build/mksquashfs build/validate 2>/dev/null # Do NOT strip build/runtime_with_magic
chmod a+x build/*
ls -lh build/*
for FILE in $(ls build/*) ; do
  echo "$FILE"
  ldd "$FILE" || true
done

bash -ex "$HERE/build-appdirs.sh"

ls -lh

mkdir -p out
cp -r build/* ./*.AppDir out/
