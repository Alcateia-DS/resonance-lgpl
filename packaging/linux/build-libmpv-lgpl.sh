#!/usr/bin/env bash
# O libmpv em modo LGPL para Linux x86_64, compilado no Ubuntu 22.04 (glibc 2.35, a base do release: o que sai daqui roda onde o
# app roda). Promovida do P1 (prototypes/p1-slint-mpv/docker/build-libmpv-lgpl-linux.sh, que usava o libass, a libplacebo e o
# dav1d do Ubuntu 24.04):
#   - libmpv.so.2 (mpv 0.41.0, -Dgpl=false) com a libplacebo 7.360.1 (LGPL 2.1+), o libass 0.17.5 (ISC) e a libdisplay-info 0.2.0
#     (MIT) estáticos dentro: o 22.04 não tem a libplacebo nova que o mpv 0.41 pede nem a libdisplay-info (sem ela o meson desliga
#     o `drm` e, junto, o `vaapi-drm`, o caminho do VAAPI no modo LGPL); o libass do sistema é o 0.15;
#   - o FFmpeg 9.0.2 compartilhado ao lado (libavcodec.so.63 e as outras; LGPL 2.1+, sem --enable-gpl/--enable-nonfree), com o
#     dav1d 1.5.4 (BSD-2) estático dentro do libavcodec: a pessoa pode trocar qualquer um deles (o que a LGPL pede);
#   - RUNPATH $ORIGIN em todos: o libmpv acha o FFmpeg na própria pasta (/usr/lib/resonance no .deb e no AppImage);
#   - do sistema: gnutls, libva/libva-drm, libdrm, gbm, EGL, o áudio (PulseAudio e ALSA), FreeType, FriBidi, HarfBuzz, fontconfig,
#     zlib e bzip2 (a lista exata sai no BUILDINFO; o Depends do .deb é ela). Sem Wayland no mpv: o 22.04 tem a wayland-client 1.20
#     e o mpv 0.41 pede 1.21; o VAAPI vai pelo nó de render DRM no X11 e no Wayland (MPV_RENDER_PARAM_DRM_DISPLAY_V2).
#
# Uso (como root, num contêiner `ubuntu:22.04` --platform linux/amd64; num runner ubuntu-22.04, com sudo):
#   INSTALAR_DEPENDENCIAS=1 packaging/linux/build-libmpv-lgpl.sh <pasta-dos-fontes> <prefixo> [<núcleos>]
#   fontes (assinaturas conferidas antes, SHA256SUMS ao lado): ffmpeg 9.0.2, mpv 0.41.0, libass 0.17.5, dav1d 1.5.4,
#   libdisplay-info 0.2.0; a libplacebo vem do git (tag assinada v7.360.1, commit conferido). O prefixo fica gravado no libavcodec
#   (o configure vai no `avcodec_configuration()`): use um caminho neutro (a release deps usou /opt/libmpv-lgpl).
# Saída: <prefixo>/dist/ com libmpv.so.2 e as bibliotecas do FFmpeg (arquivos de verdade, com o nome do SONAME, sem links), o
# LICENSE.LGPL e o Copyright do mpv, o LICENSE.md do FFmpeg e o BUILDINFO.txt (a prova do modo LGPL).
set -euo pipefail
SRC="$1"; PREFIX="$2"
JOBS="${3:-$(nproc)}"
WORK="$(mktemp -d)"
LIBPLACEBO_COMMIT=cee9b076f2c63104ccfd497fa79c39a867293ec4
OUT="$PREFIX/dist"

if [ "${INSTALAR_DEPENDENCIAS:-0}" = 1 ]; then
  # ferramentas e cabeçalhos de build (nada disto vai no pacote; as bibliotecas de execução são as do sistema de quem instala)
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    build-essential pkg-config nasm ninja-build python3 python3-pip git ca-certificates xz-utils patchelf binutils file hwdata \
    libgnutls28-dev libva-dev libdrm-dev libgbm-dev libegl-dev libpulse-dev libasound2-dev zlib1g-dev libbz2-dev \
    libfreetype-dev libfribidi-dev libharfbuzz-dev libfontconfig-dev > /dev/null
  # o mpv 0.41 pede o meson 1.3 ou mais novo (o do 22.04 é o 0.61); a mesma versão do Mac
  pip3 install -q meson==1.12.1
fi

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
mkdir -p "$PREFIX"
(cd "$SRC" && sha256sum -c --ignore-missing --quiet SHA256SUMS)

M=(--prefix="$PREFIX" --libdir=lib --buildtype=release --default-library=static)
step() { echo "== $1 ($(date +%T))"; }
have() { [ -f "$PREFIX/lib/pkgconfig/$1.pc" ] && echo "   já instalado: $1"; }
# As bibliotecas estáticas daqui entram dentro de uma compartilhada (libmpv.so.2, libavcodec.so.63): o que elas usam do sistema tem
# de ir na linha do ligador mesmo sem `pkg-config --static`. Os campos privados do .pc passam a públicos.
publicize() {
  python3 -I - "$PREFIX/lib/pkgconfig/$1.pc" <<'EOF'
import sys
path = sys.argv[1]
fields, lines = {}, []
for line in open(path).read().splitlines():
    key = line.split(':', 1)[0] if ':' in line and '=' not in line.split(':', 1)[0] else None
    if key in ('Requires', 'Requires.private', 'Libs', 'Libs.private'):
        fields[key] = (fields.get(key, '') + ' ' + line.split(':', 1)[1]).strip()
    else:
        lines.append(line)
lines.append('Requires: ' + ' '.join(v for v in (fields.get('Requires', ''), fields.get('Requires.private', '')) if v).replace(' ,', ','))
lines.append('Libs: ' + ' '.join(v for v in (fields.get('Libs', ''), fields.get('Libs.private', '')) if v))
open(path, 'w').write('\n'.join(lines) + '\n')
EOF
}

step dav1d
if ! have dav1d; then
tar -xJf "$SRC/dav1d-1.5.4.tar.xz" -C "$WORK" && cd "$WORK/dav1d-1.5.4"
meson setup build "${M[@]}" -Denable_tools=false -Denable_tests=false -Denable_examples=false -Denable_docs=false
meson install -C build > /dev/null
publicize dav1d
fi

step libdisplay-info
if ! have libdisplay-info; then
tar -xJf "$SRC/libdisplay-info-0.2.0.tar.xz" -C "$WORK" && cd "$WORK/libdisplay-info-0.2.0"
meson setup build "${M[@]}"
meson install -C build > /dev/null
publicize libdisplay-info
fi

step libass
if ! have libass; then
tar -xJf "$SRC/libass-0.17.5.tar.xz" -C "$WORK" && cd "$WORK/libass-0.17.5"
meson setup build "${M[@]}" -Dfontconfig=enabled -Dcoretext=disabled -Ddirectwrite=disabled -Dasm=enabled \
  -Dlibunibreak=disabled -Dtest=disabled -Dcompare=disabled -Dprofile=disabled -Dfuzz=disabled -Dcheckasm=disabled
meson install -C build > /dev/null
publicize libass
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
publicize libplacebo
fi

step ffmpeg
if ! have libavcodec; then
tar -xJf "$SRC/ffmpeg-9.0.2.tar.xz" -C "$WORK" && cd "$WORK/ffmpeg-9.0.2"
# Sem --enable-gpl, sem --enable-nonfree, sem --enable-version3: o configure recusa qualquer biblioteca GPL e o resultado é
# LGPL 2.1 ou posterior (conferido no fim, na licença gravada no libavcodec). O X11 (xlib/xcb) fica de fora: o mpv cria o
# VADisplay dele pelo DRM, e o app desenha pela API de render.
./configure --prefix="$PREFIX" --enable-shared --disable-static --enable-pic \
  --disable-programs --disable-doc --disable-debug \
  --disable-encoders --enable-encoder=png,mjpeg --disable-muxers --disable-devices \
  --disable-xlib --disable-libxcb --disable-vdpau --disable-vulkan --disable-sdl2 --disable-lzma \
  --enable-gnutls --enable-libdav1d --enable-vaapi --enable-libdrm > "$WORK/ffmpeg-configure.log"
{ grep -E "^License:" "$WORK/ffmpeg-configure.log"; grep -E "^#define FFMPEG_CONFIGURATION" config.h; } > "$PREFIX/ffmpeg-configure.txt"
cat "$PREFIX/ffmpeg-configure.txt"
make -j"$JOBS" > /dev/null
make install > /dev/null
cp LICENSE.md "$PREFIX/FFmpeg-LICENSE.md"
fi

step mpv
tar -xzf "$SRC/mpv-0.41.0.tar.gz" -C "$WORK" && cd "$WORK/mpv-0.41.0"
# -Dgpl=false: tira os arquivos que ainda são só GPL (X11 do mpv, vdpau, OSS, jack, DVD, CDDA, DVB, caca). O app não usa
# nenhum deles: desenha pela API de render (vo=libmpv) no OpenGL do Slint.
meson setup build --prefix="$PREFIX" --libdir=lib --buildtype=release --default-library=shared \
  -Dgpl=false -Dlibmpv=true -Dcplayer=false -Dtests=false \
  -Ddrm=enabled -Dgbm=enabled -Degl=enabled -Dvaapi=enabled -Dvaapi-drm=enabled -Dpulse=enabled -Dalsa=enabled \
  -Dwayland=disabled -Dpipewire=disabled -Dvulkan=disabled -Dsixel=disabled \
  -Dlua=disabled -Djavascript=disabled -Dlibarchive=disabled -Dlibbluray=disabled -Ddvdnav=disabled -Dcdda=disabled \
  -Drubberband=disabled -Dvapoursynth=disabled -Dzimg=disabled -Duchardet=disabled -Dlcms2=disabled -Djpeg=disabled \
  -Dsdl2-audio=disabled -Dsdl2-video=disabled -Dsdl2-gamepad=disabled -Dopenal=disabled -Dspirv-cross=disabled \
  -Dshaderc=disabled -Dmanpage-build=disabled -Dhtml-build=disabled -Dpdf-build=disabled
grep -E "^Message: List of enabled features|^ +(gpl|drm|gbm|egl|vaapi|vaapi-drm|wayland|x11|pulse|alsa|opengl|gl|vulkan|libplacebo) +:" \
  build/meson-logs/meson-log.txt | sort -u > "$WORK/mpv-summary.txt"
meson compile -C build -j "$JOBS" > /dev/null
meson install -C build > /dev/null
cp Copyright LICENSE.LGPL "$PREFIX/"

step pacote
rm -rf "$OUT"; mkdir -p "$OUT"
# só os arquivos de verdade, com o nome que o ligador procura (o SONAME), sem links
for lib in libmpv.so.2 libavcodec.so libavdevice.so libavfilter.so libavformat.so libavutil.so libswresample.so libswscale.so; do
  real="$(readlink -f "$PREFIX/lib/$lib")"
  soname="$(objdump -p "$real" | awk '/SONAME/ {print $2}')"
  cp "$real" "$OUT/$soname"
done
strip --strip-unneeded "$OUT"/*.so.*
patchelf --set-rpath '$ORIGIN' "$OUT"/*.so.*
cp "$PREFIX/LICENSE.LGPL" "$PREFIX/Copyright" "$PREFIX/FFmpeg-LICENSE.md" "$OUT/"

step prova
license="$(grep -a -o -m1 "libavcodec license: [A-Za-z0-9 .]*" "$OUT"/libavcodec.so.*)"
config="$(strings -a "$OUT"/libavcodec.so.* | grep -m1 -- "^--prefix=.*--enable-libdrm" || true)"
[ "$license" = "libavcodec license: LGPL version 2.1 or later" ] || { echo "licença do FFmpeg inesperada: $license"; exit 1; }
if grep -qE -- "--enable-(gpl|nonfree|version3)" "$PREFIX/ffmpeg-configure.txt"; then echo "o FFmpeg foi configurado fora da LGPL 2.1"; exit 1; fi
grep -qE "^ +gpl +: false" "$WORK/mpv-summary.txt" || { echo "o mpv não saiu com gpl false"; exit 1; }
# as dependências de fora da pasta (as do sistema), por arquivo e juntas
needed() { objdump -p "$1" | awk '/NEEDED/ {print $2}'; }
own="$(cd "$OUT" && ls -- *.so.*)"
{
  echo "libmpv 0.41.0 (LGPL), Linux x86_64 (glibc 2.35 ou mais nova), compilado em $(date -u +%F) num $(. /etc/os-release && echo "$PRETTY_NAME") $(uname -m), $(gcc --version | head -1)"
  echo "Receita: packaging/linux/build-libmpv-lgpl.sh (resonance-rust). Fontes (SHA-256):"
  sed 's/^/  /' "$SRC/SHA256SUMS"
  echo "  libplacebo v7.360.1 (git, tag assinada) commit $LIBPLACEBO_COMMIT"
  echo
  echo "== FFmpeg 9.0.2: o configure (sem --enable-gpl, --enable-nonfree nem --enable-version3)"
  cat "$PREFIX/ffmpeg-configure.txt"
  echo "configuração gravada dentro do libavcodec: $config"
  echo
  echo "== licença gravada no libavcodec"
  echo "$license"
  echo
  echo "== mpv 0.41.0: resumo do meson"
  cat "$WORK/mpv-summary.txt"
  echo
  echo "== arquivos (RUNPATH \$ORIGIN; as bibliotecas desta pasta se acham entre si)"
  for f in $own; do echo "$f $(stat -c %s "$OUT/$f") bytes, RUNPATH $(objdump -p "$OUT/$f" | awk '/RUNPATH/ {print $2}')"; done
  echo
  echo "== dependências de fora da pasta (objdump -p, NEEDED), juntas"
  for f in $own; do needed "$OUT/$f"; done | sort -u | grep -vxF -f <(echo "$own")
  echo
  echo "== glibc mais nova pedida"
  for f in $own; do objdump -T "$OUT/$f"; done | grep -oE "GLIBC_[0-9.]+" | sort -uV | tail -1
  echo
  echo "== funções da API de render exportadas pelo libmpv.so.2"
  objdump -T "$OUT/libmpv.so.2" | grep -oE "mpv_render_context_[a-z_]+" | sort -u | tr '\n' ' '; echo
} > "$OUT/BUILDINFO.txt"
cat "$OUT/BUILDINFO.txt"
rm -rf "$WORK"
