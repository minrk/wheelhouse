#!/bin/bash

set -e

if [[ "$@" = "nightly" ]]; then
  nightly="nightly"
fi

# default to script location, change for somewhere else
root=$(dirname "$0")

wheelhouse="$root/$nightly"
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
export CC=clang
# this one seems to be needed only for matplotlib 1.3 on Python.org Python 2.7
export CFLAGS="-I/usr/local/opt/freetype/include/freetype2"

for env in $envs; do
  source $env/bin/activate
  py=`python -c "import sys; print('%i%i' % sys.version_info[:2])"`
  test -d "$VIRTUAL_ENV/build" && rm -rf "$VIRTUAL_ENV/build"
  easy_install --upgrade setuptools pip
  pip install --upgrade wheel
  
  # base command-line args
  test -z "$nightly" || pre='--pre'
  args="$pre --use-wheel --allow-all-external --find-links $wheelhouse --download-cache $cache"
  
  # clear the cache dir before starting
  for whl in "$cache"/*.whl; do
    test "$whl" = "$cache"/*.whl && break
    rm -i "$whl"
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
      test "$whl" = "$cache"/*.whl && break
      echo ...copying cached wheel "${whl##*%2F}"
      mv $whl "$wheelhouse/${whl##*%2F}"
    done
  
    if [[ ! -z "$nightly" ]]; then
      # cleanup old wheels (pandas, numpy, etc. put sha in version)
      egg=`echo $wheel | cut -f 2 -d =`
      matches=`find $wheelhouse -depth 1 -name "$egg*cp$py*.whl" -exec stat -f '%m %N' {} \; | sort -n | cut -d ' ' -f 2`
      old=`python -c "import sys; print(' '.join(sys.argv[1:-1]))" $matches`
      set -x
      test -z $old || rm -v $old
      set +x
    fi
  done
done

