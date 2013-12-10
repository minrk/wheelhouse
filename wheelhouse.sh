#!/bin/bash

set -e

if [[ "$@" = "nightly" ]]; then
  nightly="nightly"
fi

wheelhouse="$HOME/dev/wheelhouse/$nightly"
wheels=`cat $wheelhouse/wheels.txt`
cache=/tmp/wheel-cache$nightly
test -d "$cache" || mkdir "$cache"

envs="wheels27$nightly wheels33$nightly"
# some things (matplotlib OS X backend) don't like to compile with gcc-4.2 on 10.9.
# using clang seeems to work, though
export CC=clang
for env in $envs; do
  source $HOME/env/$env/bin/activate
  py=`python -c "import sys; print('%i%i' % sys.version_info[:2])"`
  test -d "$VIRTUAL_ENV/build" && rm -rf "$VIRTUAL_ENV/build"
  pip install --upgrade wheel
  test -z "$nightly" || pre='--pre'
  for wheel in $wheels; do
    set -x
    pip wheel $pre --use-wheel --find-links "$wheelhouse" --wheel-dir "$wheelhouse" --download-cache "$cache" $wheel
    pip install $pre --use-wheel --find-links "$wheelhouse" --download-cache "$cache" $wheel
    set +x
  
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

