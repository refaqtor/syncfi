#!/bin/sh
set -e
cd "$(dirname "$0")"

if [ -e nimenv.local ]; then
  echo 'nimenv.local exists. You may use `nimenv build` instead of this script.'
  #exit 1
fi

mkdir -p .nimenv/nim
mkdir -p .nimenv/deps

NIMHASH=cd61f5e5768d4063596d6df578ae9bb5f9d52430773542987e91050b848cb1a9
if ! [ -e .nimenv/nimhash -a \( "$(cat .nimenv/nimhash)" = "$NIMHASH" \) ]; then
  echo "Downloading Nim http://nim-lang.org/download/nim-0.13.0.tar.xz (sha256: $NIMHASH)"
  wget http://nim-lang.org/download/nim-0.13.0.tar.xz -O .nimenv/nim.tar.xz
  if ! [ "$(sha256sum < .nimenv/nim.tar.xz)" = "$NIMHASH  -" ]; then
    echo "verification failed"
    exit 1
  fi
  echo "Unpacking Nim..."
  rm -r .nimenv/nim
  mkdir -p .nimenv/nim
  cd .nimenv/nim
  tar xJf ../nim.tar.xz
  mv nim-*/* .
  echo "Building Nim..."
  make -j$(getconf _NPROCESSORS_ONLN)
  cd ../..
  echo $NIMHASH > .nimenv/nimhash
fi

get_dep() {
  set -e
  cd .nimenv/deps
  name="$1"
  url="$2"
  hash="$3"
  srcpath="$4"
  new=0
  if ! [ -e "$name" ]; then
    git clone --recursive "$url" "$name"
    new=1
  fi
  if ! [ "$(cd "$name" && git rev-parse HEAD)" = "$hash" -a $new -eq 0 ]; then
     cd "$name"
     git fetch --all
     git checkout -q "$hash"
     git submodule update --init
     cd ..
  fi
  cd ../..
  echo "path: \".nimenv/deps/$name$srcpath\"" >> nim.cfg
}

echo "path: \".\"" > nim.cfg

get_dep capnp https://github.com/zielmicha/capnp.nim 702a008b8dcde2a4887a510e37bb9f9179f7da0c ''
get_dep collections https://github.com/zielmicha/collections.nim 3f7352b683f26f3c18ad8c68e1a23f0b86b61cb6 ''
get_dep docopt https://github.com/docopt/docopt.nim bf2124533a36eadf3999c1ad6a2d8300114f5198 /src/
get_dep libcommon https://github.com/networkosnet/libcommon e51cc7898529b80741898b7029b76b3559b8fdf2 ''
get_dep niceconf https://github.com/networkosnet/niceconf ccf617c397e6c8933d9fca910524136c45e3af8a ''
get_dep nimbloom https://github.com/zielmicha/nim-bloom 5a5ff9c8e2aec1a6b9e6942486ff53ebe152b72a ''
get_dep nimsnappy https://github.com/dfdeshom/nimsnappy 22f4597593c1f8728e8a45a7cacc0579a5d2d4b8 ''
get_dep reactor https://github.com/zielmicha/reactor.nim 554bc66175d1ec4e148a55fa29622138e0b5ddd8 ''
get_dep reactorfuse https://github.com/zielmicha/reactorfuse 8a57acdad393e0d3fd8cfa927dc857526d486900 ''
get_dep sodium https://github.com/zielmicha/libsodium.nim 66579d24655009d738efed71138cad9f62b73b05 ''

echo '# reactor.nim requires pthreads
threads: "on"

# enable debugging
passC: "-g"
passL: "-g"

verbosity: "0"
hint[ConvFromXtoItselfNotNeeded]: "off"
hint[XDeclaredButNotUsed]: "off"

debugger: "native"

@if release:
  gcc.options.always = "-w -fno-strict-overflow"
  gcc.cpp.options.always = "-w -fno-strict-overflow"
  clang.options.always = "-w -fno-strict-overflow"
  clang.cpp.options.always = "-w -fno-strict-overflow"
  obj_checks: on
  field_checks: on
  bound_checks: on
@end' >> nim.cfg

mkdir -p bin
ln -sf ../.nimenv/nim/bin/nim bin/nim

echo "building server"; nim c --out:"$PWD/bin/server" syncfi/server.nim
echo "building syncfi"; nim c --out:"$PWD/bin/syncfi" syncfi/main.nim
