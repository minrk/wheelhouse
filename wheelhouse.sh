#!/bin/bash
export LANG="en_US.UTF-8"
set -e
PATH=/usr/local/bin:$PATH

if [[ "$1" = "nightly" ]]; then
  nightly="nightly"
  shift
fi

if [[ ! -z "$1" ]]; then
  upload_dest="$1"
  shift
fi

upload="rsync -varuP --delete"

# default to script location, change for somewhere else
root=$(dirname "$0" | sed s@/\$@@)
wheelhouse="$root"

if [[ ! -z "$nightly" ]]; then
  wheelhouse="$root/$nightly"
fi

wheels=`cat $wheelhouse/wheels.txt`

cache=/tmp/wheel-cache$nightly
test -d "$cache" || mkdir "$cache"

envroot="$HOME/env"

if [[ -z "$VIRTUAL_ENV" ]]; then
  envs="$envroot/wheels27$nightly $envroot/wheels33$nightly $envroot/wheels34$nightly"
else
  envs="$VIRTUAL_ENV"
fi
# some things (matplotlib OS X backend) don't like to compile with gcc-4.2 on 10.9.
# using clang seeems to work, though
export CC=cc
export CXX=c++
# this one seems to be needed only for matplotlib 1.3 for freetype and libpng
export CFLAGS="-I/usr/local/opt/freetype/include/freetype2"

for env in $envs; do
  source $env/bin/activate
  py=`python -c "import sys; print('%i%i' % sys.version_info[:2])"`
  test -d "$VIRTUAL_ENV/build" && rm -rf "$VIRTUAL_ENV/build"
  easy_install --upgrade setuptools pip
  pip install --upgrade wheel
  
  # base command-line args
  test -z "$nightly" || pre='--pre'
  args="$pre --use-wheel --allow-all-external --find-links $root --find-links $wheelhouse --download-cache $cache"
  
  # clear the cache dir before starting
  for whl in "$cache"/*.whl; do
    test "$whl" = "$cache"'/*.whl' && break
    rm -f "$whl"
  done
  
  # start building wheels
  for wheel in $wheels; do
    wargs="$args --allow-insecure $wheel"
    set +e
    set -x
    pip wheel $wargs --wheel-dir "$wheelhouse" $wheel && pip install $wargs $wheel
    set +x
    set -e
  
    # cache trick from https://github.com/pypa/pip/issues/1310#issuecomment-29760070
    for whl in "$cache"/*.whl; do
      test "$whl" = "$cache"'/*.whl' && break
      echo ...copying cached wheel "${whl##*%2F}"
      mv $whl "$root/${whl##*%2F}"
    done
  
    # cleanup old wheels (pandas, numpy, etc. put sha in version)
    egg=`echo $wheel | cut -f 2 -d =`
    matches=`find $wheelhouse -depth 1 -name "$egg*cp$py*.whl" -exec stat -f '%m %N' {} \; | sort -n | cut -d ' ' -f 2`
    old=`python -c "import sys; print(' '.join(sys.argv[1:-1]))" $matches`
    set -x
    test -z $old || rm -v $old
    set +x
  done
done

# tell pip that all of the 10.6 wheels will also work on 10.9 (System Python and Homebrew / user-compiled)
for file in $(find "$wheelhouse" -name '*-macosx_10_6_intel.whl'); do
  mv -v $file $(echo $file | sed s/macosx_10_6_intel.whl/macosx_10_6_intel.macosx_10_9_intel.macosx_10_9_x86_64.whl/)
done

if [[ ! -z "$upload_dest" ]]; then
  cd $root
  echo "sending wheels to $upload_dest/"
  $upload -- * "$upload_dest/"
fi