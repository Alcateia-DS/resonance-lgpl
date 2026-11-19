#!/usr/bin/env bash
# O libmpv em modo LGPL para Windows x86_64, compilado de forma cruzada no Linux (mingw-w64 13 do Ubuntu 24.04, sem toolchain de
# terceiros): um `libmpv-2.dll` só, com o FFmpeg (LGPL 2.1+, sem --enable-gpl/--enable-nonfree; TLS pelo schannel, D3D11VA e
# DXVA2), libplacebo (LGPL 2.1+, só OpenGL), libass (ISC, fontes pelo DirectWrite), FreeType (FTL), HarfBuzz (MIT), FriBidi
# (LGPL 2.1+) e zlib dentro, todos estáticos. O DLL fica ao lado do resonance.exe e é aberto em tempo de execução: a pessoa pode
# trocá-lo (o que a LGPL pede); as outras dependências são DLLs do próprio Windows. Promovida do P1
# (prototypes/p1-slint-mpv/docker/build-libmpv-lgpl-windows.sh, a imagem docker/Dockerfile.windows); o DLL da release "deps"
# (scripts/deps-release.sh) é o que ela compilou no P1, com o log ao lado.
#
# Uso (no contêiner da imagem do P1, ubuntu:24.04 com mingw-w64, meson, nasm e pkg-config):
#   packaging/windows/build-libmpv-lgpl.sh <pasta-dos-fontes> <prefixo>
#   fontes (assinaturas conferidas antes, SHA256SUMS ao lado): ffmpeg 9.0.2, mpv 0.41.0, freetype 2.14.3, fribidi 1.0.17,
#   harfbuzz 14.5.1, libass 0.17.5; a libplacebo vem do git (tag assinada v7.360.1, commit conferido). O prefixo fica gravado no
#   DLL (o configure do FFmpeg vai no `avcodec_configuration()`): use um caminho neutro (o P1 usou /opt/win64).
# Saída: <prefixo>/bin/libmpv-2.dll e <prefixo>/BUILDINFO.txt (a prova do modo LGPL), com o LICENSE.LGPL, o Copyright do mpv e o
# LICENSE.md do FFmpeg ao lado.
set -euo pipefail
SRC="$1"; PREFIX="$2"
JOBS="$(nproc)"
WORK="$(mktemp -d)"
HOST=x86_64-w64-mingw32
LIBPLACEBO_COMMIT=cee9b076f2c63104ccfd497fa79c39a867293ec4
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:/usr/$HOST/lib/pkgconfig"
export PKG_CONFIG_PATH=""
mkdir -p "$PREFIX"
(cd "$SRC" && sha256sum -c --ignore-missing --quiet SHA256SUMS)

CROSS="$WORK/cross.ini"
cat > "$CROSS" <<EOF
[binaries]
c = '$HOST-gcc-posix'
cpp = '$HOST-g++-posix'
ar = '$HOST-ar'
strip = '$HOST-strip'
windres = '$HOST-windres'
dlltool = '$HOST-dlltool'
pkg-config = 'pkg-config'
nasm = 'nasm'

[built-in options]
c_args = ['-I$PREFIX/include', '-I/usr/$HOST/include']
cpp_args = ['-I$PREFIX/include']
c_link_args = ['-L$PREFIX/lib']
cpp_link_args = ['-L$PREFIX/lib']

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
M=(--cross-file "$CROSS" --prefix="$PREFIX" --libdir=lib --buildtype=release --default-library=static -Dprefer_static=true)

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
meson setup build "${M[@]}" -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled \
  -Dicu=disabled -Dgraphite2=disabled -Dpng=disabled -Dzlib=disabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled \
  -Dintrospection=disabled -Dbenchmark=disabled -Dsubset=disabled -Draster=disabled -Dvector=disabled -Dgpu=disabled \
  -Dwasm=disabled
meson install -C build > /dev/null
fi

step libass
if ! have libass; then
tar -xJf "$SRC/libass-0.17.5.tar.xz" -C "$WORK" && cd "$WORK/libass-0.17.5"
meson setup build "${M[@]}" -Dfontconfig=disabled -Ddirectwrite=enabled -Dasm=enabled -Dlibunibreak=disabled \
  -Dtest=disabled -Dcompare=disabled -Dprofile=disabled -Dfuzz=disabled -Dcheckasm=disabled
meson install -C build > /dev/null
fi

step ffmpeg
if ! have libavcodec; then
tar -xJf "$SRC/ffmpeg-9.0.2.tar.xz" -C "$WORK" && cd "$WORK/ffmpeg-9.0.2"
# Sem --enable-gpl, sem --enable-nonfree, sem --enable-version3: o configure recusa qualquer biblioteca GPL e o resultado é
# LGPL 2.1 ou posterior (conferido no fim, na licença gravada dentro do DLL)
./configure --prefix="$PREFIX" --target-os=mingw32 --arch=x86_64 --cross-prefix="$HOST-" --cc="$HOST-gcc-posix" \
  --cxx="$HOST-g++-posix" --pkg-config=pkg-config --pkg-config-flags=--static \
  --enable-static --disable-shared --disable-programs --disable-doc --disable-debug \
  --disable-encoders --enable-encoder=png,mjpeg --disable-muxers --disable-devices \
  --enable-schannel --enable-d3d11va --enable-dxva2 --enable-zlib > "$WORK/ffmpeg-configure.log"
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
[ "$(git rev-parse HEAD)" = "$LIBPLACEBO_COMMIT" ] || { echo "a tag v7.360.1 da libplacebo aponta para outro commit"; exit 1; }
git -c advice.detachedHead=false submodule -q update --init --depth 1 3rdparty/glad 3rdparty/jinja 3rdparty/markupsafe 3rdparty/fast_float 3rdparty/Vulkan-Headers
meson setup build "${M[@]}" -Dvulkan=disabled -Dopengl=enabled -Dd3d11=disabled -Dglslang=disabled -Dshaderc=disabled \
  -Dlcms=disabled -Ddovi=disabled -Dlibdovi=disabled -Dxxhash=disabled -Dunwind=disabled -Ddemos=false -Dtests=false
meson install -C build > /dev/null
fi

step mpv
tar -xzf "$SRC/mpv-0.41.0.tar.gz" -C "$WORK" && cd "$WORK/mpv-0.41.0"
# um DLL só: libgcc, libstdc++ (do HarfBuzz) e winpthread entram estáticos
meson setup build "${M[@]}" --default-library=shared \
  -Dc_link_args="-L$PREFIX/lib -static -lstdc++" -Dcpp_link_args="-L$PREFIX/lib -static" \
  -Dgpl=false -Dlibmpv=true -Dcplayer=false -Dtests=false \
  -Dlua=disabled -Djavascript=disabled -Dlibarchive=disabled -Dlibbluray=disabled -Ddvdnav=disabled -Dcdda=disabled \
  -Drubberband=disabled -Dvapoursynth=disabled -Dzimg=disabled -Duchardet=disabled -Dlcms2=disabled -Djpeg=disabled \
  -Diconv=disabled -Dsdl2-audio=disabled -Dsdl2-video=disabled -Dsdl2-gamepad=disabled -Dopenal=disabled \
  -Dd3d11=disabled -Dvulkan=disabled -Dspirv-cross=disabled -Dshaderc=disabled -Degl-angle=disabled \
  -Dgl-win32=enabled -Dgl-dxinterop=enabled -Dd3d-hwaccel=enabled -Dd3d9-hwaccel=enabled -Dgl-dxinterop-d3d9=enabled \
  -Dwasapi=enabled -Dwin32-smtc=disabled \
  -Dmanpage-build=disabled -Dhtml-build=disabled -Dpdf-build=disabled
grep -E "^Message: List of enabled features|^ +(gpl|opengl|gl-win32|gl-dxinterop|d3d-hwaccel|d3d11|vulkan|wasapi) +:" \
  build/meson-logs/meson-log.txt | sort -u > "$WORK/mpv-summary.txt"
meson compile -C build -j "$JOBS" > /dev/null
meson install -C build > /dev/null
cp Copyright LICENSE.LGPL "$PREFIX/"

step prova
DLL="$PREFIX/bin/libmpv-2.dll"
license="$(grep -a -o -m1 "libavcodec license: [A-Za-z0-9 .]*" "$DLL")"
config="$(strings -a "$DLL" | grep -m1 -- "^--prefix=.*--enable-zlib" || true)"
[ "$license" = "libavcodec license: LGPL version 2.1 or later" ] || { echo "licença do FFmpeg inesperada: $license"; exit 1; }
if grep -qE -- "--enable-(gpl|nonfree|version3)" "$PREFIX/ffmpeg-configure.txt"; then echo "o FFmpeg foi configurado fora da LGPL 2.1"; exit 1; fi
grep -qE "^ +gpl +: false" "$WORK/mpv-summary.txt" || { echo "o mpv não saiu com gpl false"; exit 1; }
{
  echo "libmpv 0.41.0 (LGPL), Windows x86_64, compilado em $(date -u +%F) de forma cruzada num $(. /etc/os-release && echo "$PRETTY_NAME"), $("$HOST-gcc-posix" --version | head -1)"
  echo "Receita: packaging/windows/build-libmpv-lgpl.sh (resonance-rust). Fontes (SHA-256):"
  sed 's/^/  /' "$SRC/SHA256SUMS"
  echo "  libplacebo v7.360.1 (git, tag assinada) commit $LIBPLACEBO_COMMIT"
  echo
  echo "== FFmpeg 9.0.2: o configure (sem --enable-gpl, --enable-nonfree nem --enable-version3)"
  cat "$PREFIX/ffmpeg-configure.txt"
  echo "configuração gravada dentro do DLL: $config"
  echo
  echo "== licença gravada no FFmpeg de dentro do libmpv-2.dll"
  echo "$license"
  echo
  echo "== mpv 0.41.0: resumo do meson"
  cat "$WORK/mpv-summary.txt"
  echo
  echo "== DLLs que o libmpv-2.dll importa (objdump -p; só do Windows)"
  "$HOST-objdump" -p "$DLL" | grep "DLL Name" | sort -u
  echo
  echo "== funções da API de render exportadas"
  "$HOST-objdump" -p "$DLL" | grep -oE "mpv_render_context_[a-z_]+" | sort -u | tr '\n' ' '; echo
} > "$PREFIX/BUILDINFO.txt"
cat "$PREFIX/BUILDINFO.txt"
rm -rf "$WORK"
