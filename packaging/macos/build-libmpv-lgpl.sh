#!/usr/bin/env bash
# O libmpv em modo LGPL para macOS arm64: um `libmpv.2.dylib` só, com o FFmpeg (LGPL 2.1+, sem --enable-gpl/--enable-nonfree;
# TLS pelo Secure Transport do sistema, VideoToolbox e AudioToolbox), libplacebo (LGPL 2.1+), libass (ISC, fontes pelo CoreText),
# FreeType (FTL), HarfBuzz (MIT) e FriBidi (LGPL 2.1+) dentro, todos estáticos. Fora dele, só bibliotecas e frameworks do próprio
# macOS. O dylib fica em Contents/Frameworks e é aberto em tempo de execução: a pessoa pode trocá-lo (o que a LGPL pede).
# É a receita do Windows do P1 (packaging/windows/build-libmpv-lgpl.sh), compilada no próprio Mac. Vai para a release "deps"
# (scripts/deps-release.sh); o release do app só a copia, conferida pelo packaging/deps/SHA256SUMS.
#
# Uso: packaging/macos/build-libmpv-lgpl.sh <pasta-dos-fontes> <prefixo>
#   fontes (assinaturas conferidas antes, SHA256SUMS ao lado): ffmpeg 9.0.2, mpv 0.41.0, freetype 2.14.3, fribidi 1.0.17,
#   harfbuzz 14.5.1, libass 0.17.5; a libplacebo vem do git (tag assinada v7.360.1, commit conferido).
#   O prefixo fica gravado dentro do dylib (o configure do FFmpeg vai no `avcodec_configuration()`): use um caminho neutro, sem o
#   nome de quem compila (a release deps usou /tmp/libmpv-lgpl-macos).
# Pede: meson, ninja, nasm e pkg-config (ferramentas de build; nada delas vai no app) e as Command Line Tools do Xcode.
# Saída: <prefixo>/lib/libmpv.2.dylib e <prefixo>/BUILDINFO.txt (a prova do modo LGPL), com o LICENSE.LGPL, o Copyright do mpv
# e o LICENSE.md do FFmpeg ao lado.
set -euo pipefail
SRC="$1"; PREFIX="$2"
JOBS="$(sysctl -n hw.ncpu)"
WORK="$(mktemp -d)"
LIBPLACEBO_COMMIT=cee9b076f2c63104ccfd497fa79c39a867293ec4
export MACOSX_DEPLOYMENT_TARGET=11.0
export CFLAGS="-mmacosx-version-min=11.0 -arch arm64" CXXFLAGS="-mmacosx-version-min=11.0 -arch arm64"
export LDFLAGS="-mmacosx-version-min=11.0 -arch arm64" OBJCFLAGS="-mmacosx-version-min=11.0 -arch arm64"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_PATH=""
mkdir -p "$PREFIX"
(cd "$SRC" && shasum -a 256 -c --ignore-missing SHA256SUMS > /dev/null)

M=(--prefix="$PREFIX" --libdir=lib --buildtype=release --default-library=static -Dprefer_static=true)
step() { echo "== $1 ($(date +%T))"; }
# etapas já instaladas no prefixo (o .pc existe) são puladas: refazer só o que mudou
have() { [ -f "$PREFIX/lib/pkgconfig/$1.pc" ] && echo "   já instalado: $1"; }

step freetype
if ! have freetype2; then
tar -xJf "$SRC/freetype-2.14.3.tar.xz" -C "$WORK" && cd "$WORK/freetype-2.14.3"
meson setup build "${M[@]}" -Dharfbuzz=disabled -Dpng=disabled -Dbzip2=disabled -Dbrotli=disabled -Dzlib=internal -Dtests=disabled
meson install -C build > /dev/null
fi

step fribidi
if ! have fribidi; then
tar -xJf "$SRC/fribidi-1.0.17.tar.xz" -C "$WORK" && cd "$WORK/fribidi-1.0.17"
meson setup build "${M[@]}" -Ddocs=false -Dbin=false -Dtests=false
meson install -C build > /dev/null
fi

step harfbuzz
if ! have harfbuzz; then
tar -xJf "$SRC/harfbuzz-14.5.1.tar.xz" -C "$WORK" && cd "$WORK/harfbuzz-14.5.1"
meson setup build "${M[@]}" -Dfreetype=enabled -Dcoretext=disabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled \
  -Dchafa=disabled -Dicu=disabled -Dgraphite2=disabled -Dpng=disabled -Dzlib=disabled -Dtests=disabled -Ddocs=disabled \
  -Dutilities=disabled -Dintrospection=disabled -Dbenchmark=disabled -Dsubset=disabled -Draster=disabled -Dvector=disabled \
  -Dgpu=disabled -Dwasm=disabled
meson install -C build > /dev/null
fi

step libass
if ! have libass; then
tar -xJf "$SRC/libass-0.17.5.tar.xz" -C "$WORK" && cd "$WORK/libass-0.17.5"
meson setup build "${M[@]}" -Dfontconfig=disabled -Dcoretext=enabled -Ddirectwrite=disabled -Dasm=enabled \
  -Dlibunibreak=disabled -Dtest=disabled -Dcompare=disabled -Dprofile=disabled -Dfuzz=disabled -Dcheckasm=disabled
meson install -C build > /dev/null
fi

step ffmpeg
if ! have libavcodec; then
tar -xJf "$SRC/ffmpeg-9.0.2.tar.xz" -C "$WORK" && cd "$WORK/ffmpeg-9.0.2"
# Sem --enable-gpl, sem --enable-nonfree, sem --enable-version3: o configure recusa qualquer biblioteca GPL e o resultado é
# LGPL 2.1 ou posterior (conferido abaixo e no fim, na licença gravada dentro do dylib)
./configure --prefix="$PREFIX" --arch=arm64 --cc=clang --pkg-config-flags=--static \
  --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" \
  --enable-static --disable-shared --enable-pic --disable-programs --disable-doc --disable-debug \
  --disable-encoders --enable-encoder=png,mjpeg --disable-muxers --disable-devices \
  --enable-securetransport --enable-videotoolbox --enable-audiotoolbox --enable-zlib > "$WORK/ffmpeg-configure.log"
# a prova do modo LGPL fica no prefixo (as etapas puladas numa segunda rodada não perdem o que o configure disse)
{ grep -E "^License:" "$WORK/ffmpeg-configure.log"; grep -E "^#define FFMPEG_CONFIGURATION" config.h; } > "$PREFIX/ffmpeg-configure.txt"
cat "$PREFIX/ffmpeg-configure.txt"
make -j"$JOBS" > /dev/null
make install > /dev/null
cp LICENSE.md "$PREFIX/FFmpeg-LICENSE.md"
fi

step libplacebo
if ! have libplacebo; then
git clone -q --depth 1 --branch v7.360.1 https://github.com/haasn/libplacebo "$WORK/libplacebo"
cd "$WORK/libplacebo"
# a tag é assinada (conferida no GitHub); o commit dela fica preso aqui
[ "$(git rev-parse HEAD)" = "$LIBPLACEBO_COMMIT" ] || { echo "a tag v7.360.1 da libplacebo aponta para outro commit"; exit 1; }
git -c advice.detachedHead=false submodule -q update --init --depth 1 3rdparty/glad 3rdparty/jinja 3rdparty/markupsafe 3rdparty/fast_float 3rdparty/Vulkan-Headers
meson setup build "${M[@]}" -Dvulkan=disabled -Dopengl=enabled -Dd3d11=disabled -Dglslang=disabled -Dshaderc=disabled \
  -Dlcms=disabled -Ddovi=disabled -Dlibdovi=disabled -Dxxhash=disabled -Dunwind=disabled -Ddemos=false -Dtests=false
meson install -C build > /dev/null
fi

step mpv
tar -xzf "$SRC/mpv-0.41.0.tar.gz" -C "$WORK" && cd "$WORK/mpv-0.41.0"
# o render do app é OpenGL (o femtovg do Slint) pela API de render (vo=libmpv): o `gl-cocoa` só existe para ligar o
# `videotoolbox-gl` (a decodificação na GPU sem cópia). No mpv 0.41 o `cocoa` pede o Swift (o clipboard-mac.m inclui o
# cabeçalho gerado dele; os .swift do mpv são LGPL), que liga no Swift do próprio macOS (/usr/lib/swift, desde o 10.14.4); a
# janela do próprio mpv (cocoa-cb) fica de fora
meson setup build "${M[@]}" --default-library=shared \
  -Dgpl=false -Dlibmpv=true -Dcplayer=false -Dtests=false \
  -Dcocoa=enabled -Dgl-cocoa=enabled -Dvideotoolbox-gl=enabled -Dcoreaudio=enabled -Dswift-build=enabled \
  -Dmacos-cocoa-cb=disabled -Dmacos-media-player=disabled -Dmacos-touchbar=disabled -Dvulkan=disabled \
  -Dlua=disabled -Djavascript=disabled -Dlibarchive=disabled -Dlibbluray=disabled -Ddvdnav=disabled -Dcdda=disabled \
  -Drubberband=disabled -Dvapoursynth=disabled -Dzimg=disabled -Duchardet=disabled -Dlcms2=disabled -Djpeg=disabled \
  -Dsdl2-audio=disabled -Dsdl2-video=disabled -Dsdl2-gamepad=disabled -Dopenal=disabled -Dspirv-cross=disabled \
  -Dshaderc=disabled -Dmanpage-build=disabled -Dhtml-build=disabled -Dpdf-build=disabled
grep -E "^Message: List of enabled features|^ +(gpl|cocoa|gl-cocoa|videotoolbox-gl|coreaudio|macos-cocoa-cb|vulkan|swift-build) +:" \
  build/meson-logs/meson-log.txt | sort -u > "$WORK/mpv-summary.txt"
meson compile -C build -j "$JOBS" > /dev/null
meson install -C build > /dev/null
cp Copyright LICENSE.LGPL "$PREFIX/"

step prova
DYLIB="$PREFIX/lib/libmpv.2.dylib"
# o id que o app procura (Contents/Frameworks, pelo @rpath); o install_name_tool invalida a assinatura ad hoc do ligador
install_name_tool -id "@rpath/libmpv.2.dylib" "$DYLIB" 2> /dev/null
codesign --force --sign - --timestamp=none "$DYLIB"
license="$(grep -a -o -m1 "libavcodec license: [A-Za-z0-9 .]*" "$DYLIB")"
config="$(strings -a "$DYLIB" | grep -m1 -- "^--prefix=.*--enable-zlib" || true)"
# o modo LGPL é condição: sem ele, nada sai daqui
[ "$license" = "libavcodec license: LGPL version 2.1 or later" ] || { echo "licença do FFmpeg inesperada: $license"; exit 1; }
if grep -qE -- "--enable-(gpl|nonfree|version3)" "$PREFIX/ffmpeg-configure.txt"; then echo "o FFmpeg foi configurado fora da LGPL 2.1"; exit 1; fi
grep -qE "^ +gpl +: false" "$WORK/mpv-summary.txt" || { echo "o mpv não saiu com gpl false"; exit 1; }
{
  echo "libmpv 0.41.0 (LGPL), macOS arm64 (macOS 11 ou mais novo), compilado em $(date -u +%F) num $(sw_vers -productName) $(sw_vers -productVersion), $(clang --version | head -1)"
  echo "Receita: packaging/macos/build-libmpv-lgpl.sh (resonance-rust). Fontes (SHA-256):"
  sed 's/^/  /' "$SRC/SHA256SUMS"
  echo "  libplacebo v7.360.1 (git, tag assinada) commit $LIBPLACEBO_COMMIT"
  echo
  echo "== FFmpeg 9.0.2: o configure (sem --enable-gpl, --enable-nonfree nem --enable-version3)"
  cat "$PREFIX/ffmpeg-configure.txt"
  echo "configuração gravada dentro do dylib: $config"
  echo
  echo "== licença gravada no FFmpeg de dentro do libmpv.2.dylib"
  echo "$license"
  echo
  echo "== mpv 0.41.0: resumo do meson"
  cat "$WORK/mpv-summary.txt"
  echo
  echo "== bibliotecas que o libmpv.2.dylib usa (otool -L; só do sistema)"
  otool -L "$DYLIB" | tail -n +2
  echo
  echo "== macOS mínimo (vtool -show-build)"
  vtool -show-build "$DYLIB" | grep -E "minos|platform"
  echo
  echo "== funções da API de render exportadas"
  nm -gU "$DYLIB" | grep -oE "_mpv_render_context_[a-z_]+" | sort -u | tr '\n' ' '; echo
} > "$PREFIX/BUILDINFO.txt"
cat "$PREFIX/BUILDINFO.txt"
# nada de /opt/homebrew nem de outra máquina: só bibliotecas e frameworks do sistema
if otool -L "$DYLIB" | tail -n +2 | grep -vE "^\s+(/usr/lib/|/System/Library/|@rpath/libmpv)"; then
  echo "o libmpv depende de bibliotecas de fora do sistema (acima)"; exit 1
fi
rm -rf "$WORK"
