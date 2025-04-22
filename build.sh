#!/usr/bin/env bash
set -e

JSONCPP_VERSION=1.9.5
CRYPTOPP_VERSION=8_9_0
TARGETS=("win32" "win64" "linux64")

# Define toolchain per target
declare -A CC_MAP=(
  ["win32"]="i686-w64-mingw32-clang"
  ["win64"]="x86_64-w64-mingw32-clang"
  ["linux64"]="clang"
)
declare -A CXX_MAP=(
  ["win32"]="i686-w64-mingw32-clang++"
  ["win64"]="x86_64-w64-mingw32-clang++"
  ["linux64"]="clang++"
)
declare -A SYSTEM_NAME_MAP=(
  ["win32"]="Windows"
  ["win64"]="Windows"
  ["linux64"]="Linux"
)

build_jsoncpp() {
  local target=$1
  local build_dir=build/$target/deps/jsoncpp
  mkdir -p "$build_dir"
  pushd "$build_dir"

  if [ ! -d "jsoncpp-${JSONCPP_VERSION}" ]; then
    wget -q https://github.com/open-source-parsers/jsoncpp/archive/${JSONCPP_VERSION}.tar.gz -O jsoncpp.tar.gz
    tar xf jsoncpp.tar.gz
  fi

  cmake -S "jsoncpp-${JSONCPP_VERSION}" -B . \
    -DCMAKE_SYSTEM_NAME=${SYSTEM_NAME_MAP[$target]} \
    -DCMAKE_C_COMPILER=${CC_MAP[$target]} \
    -DCMAKE_CXX_COMPILER=${CXX_MAP[$target]} \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DJSONCPP_WITH_TESTS=OFF

  cmake --build .
  popd
}

build_cryptopp() {
  local target=$1
  local build_dir=build/$target/deps/cryptopp
  mkdir -p "$build_dir"
  pushd "$build_dir"

  if [ ! -d "cryptopp" ]; then
    wget -q https://github.com/weidai11/cryptopp/archive/CRYPTOPP_${CRYPTOPP_VERSION}.zip -O cryptopp.zip
    unzip -oq cryptopp.zip
    mv "cryptopp-CRYPTOPP_${CRYPTOPP_VERSION}" cryptopp
    sed -i 's/(defined(CRYPTOPP_WIN32_AVAILABLE) && defined(CRYPTOPP_LLVM_CLANG_VERSION))/false/' cryptopp/config_cpu.h
  fi

  if [[ "$target" == "linux64" ]]; then
    make -C cryptopp -f GNUmakefile \
      CXX="${CXX_MAP[$target]}" \
      CXXFLAGS="-DNDEBUG -O3 -std=c++17" \
      static

  else
    make -C cryptopp -f GNUmakefile-cross \
      CXX="${CXX_MAP[$target]}" \
      CXXFLAGS="-DNDEBUG -O3 -std=c++17 -static-libstdc++ -static-libgcc" \
      static
  fi

  popd
}

build_uid() {
  local target=$1
  local build_dir=build/$target
  mkdir -p "$build_dir"
  pushd "$build_dir"

  rm -f CMakeCache.txt
  cmake ../.. \
    -DCMAKE_SYSTEM_NAME=${SYSTEM_NAME_MAP[$target]} \
    -DCMAKE_C_COMPILER=${CC_MAP[$target]} \
    -DCMAKE_CXX_COMPILER=${CXX_MAP[$target]} \
    -DCMAKE_BUILD_TYPE=Release \
    -DJSONCPP_LIBRARIES=$(pwd)/deps/jsoncpp/lib/libjsoncpp.a \
    -DJSONCPP_INCLUDE_DIRS=$(pwd)/deps/jsoncpp/jsoncpp-${JSONCPP_VERSION}/include \
    -DCRYPTOPP_LIBRARIES=$(pwd)/deps/cryptopp/cryptopp/libcryptopp.a \
    -DCRYPTOPP_INCLUDE_DIRS=$(pwd)/deps/cryptopp \
    -DUID_SKIP_LEGACY=On \
    -DUID_PUBKEY_BYTES="$(../../encode_openssl_modulus.py $(openssl rsa -noout -inform PEM -in ../../faf_pub.pem -pubin -modulus))"

  cmake --build .
  popd
}

#for target in "${TARGETS[@]}"; do
for target in $1; do
  echo "Building for $target..."
  build_jsoncpp "$target"
  build_cryptopp "$target"
  build_uid "$target"
  echo "Done building for $target"
done
