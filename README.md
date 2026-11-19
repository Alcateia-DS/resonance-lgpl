<!-- O README do repositório público Alcateia-DS/resonance-lgpl. Este arquivo é o molde: o scripts/lgpl-fontes.sh troca 0.41.0, 9.0.2,
     fontes-libmpv-0.41.0-ffmpeg-9.0.2 e https://github.com/Alcateia-DS/resonance-lgpl e grava o resultado em dist/resonance-lgpl/README.md (fora do git). Nada daqui é lido pelo app. -->
# Resonance: fontes e receitas do libmpv e do FFmpeg (LGPL) · source code and recipes for libmpv and FFmpeg

[Português](#português) · [English](#english)

## Português

O [Resonance](https://theresonances.com), o media center da Alcateia DS para Windows, Linux e macOS, toca vídeo com o **libmpv**
(mpv 0.41.0) e o **FFmpeg** 9.0.2. As duas bibliotecas são software livre sob a **GNU Lesser General Public License, versão 2.1 ou
posterior** (LGPL 2.1+). O libmpv vai no pacote do Resonance como um arquivo separado, aberto em tempo de execução (no Windows e no Mac,
com o FFmpeg dentro dele; no Linux, com o FFmpeg em arquivos ao lado): você pode trocar esses arquivos por uma versão sua, e o `LICENSE` do
Resonance garante isso e a engenharia reversa necessária para depurar a troca (seção 6 da LGPL).

Este repositório tem tudo o que a LGPL pede para você fazer isso e para conferir o que o Resonance entrega:

- os **fontes exatos** dos pacotes que entraram nos binários: a release [`fontes-libmpv-0.41.0-ffmpeg-9.0.2`](https://github.com/Alcateia-DS/resonance-lgpl/releases/tag/fontes-libmpv-0.41.0-ffmpeg-9.0.2), com o `SHA256SUMS` e as
  assinaturas dos autores;
- as **receitas de compilação** dos três sistemas (`packaging/linux`, `packaging/macos` e `packaging/windows`), as mesmas que
  compilaram os binários do Resonance;
- o **BUILDINFO** de cada sistema (`packaging/deps/BUILDINFO-*.txt`): o `configure` do FFmpeg, o resumo do meson do mpv, as
  bibliotecas do sistema que cada arquivo usa e o SHA-256 de cada fonte;
- os **textos das licenças** (`packaging/deps/licenses/`).

Nenhuma parte GPL entrou: o FFmpeg é configurado sem `--enable-gpl`, `--enable-nonfree` e `--enable-version3` (a licença gravada nele
é "LGPL version 2.1 or later"), e o mpv, com `-Dgpl=false`.

### Os fontes

Todos na release `fontes-libmpv-0.41.0-ffmpeg-9.0.2`. O `SHA256SUMS` (também aqui, na raiz) tem o SHA-256 de cada pacote.

| Pacote | Versão | Licença | Arquivos | De onde vem e como conferir |
|---|---|---|---|---|
| mpv | 0.41.0 | LGPL 2.1+ (`-Dgpl=false`) | `mpv-0.41.0.tar.gz` | o tarball da tag `v0.41.0` no GitHub (assinada e verificada por ele); o commit dentro do tarball (`gzip -dc mpv-0.41.0.tar.gz \| git get-tar-commit-id`) é `41f6a645068483470267271e1d09966ca3b9f413` |
| FFmpeg | 9.0.2 | LGPL 2.1+ | `ffmpeg-9.0.2.tar.xz`, `.asc`, `ffmpeg-devel.asc` | a chave "FFmpeg release signing key", impressão `FCF9 86EA 15E6 E293 A564 4F10 B432 2F04 D676 58D8` (a de ffmpeg.org) |
| libplacebo | 7.360.1 | LGPL 2.1+ | `libplacebo-7.360.1.tar.xz`, `libplacebo-7.360.1.submodules.txt` | a tag `v7.360.1` (commit `cee9b076f2c63104ccfd497fa79c39a867293ec4`, assinada e verificada pelo GitHub) com os cinco submódulos que o build usa já dentro; os seis, com os commits, estão no `.submodules.txt` |
| libass | 0.17.5 | ISC | `libass-0.17.5.tar.xz`, `.asc` | Oneric, `DDAF C19E 46B2 AD2D 6B26 F843 97A0 8E0C FFD7 0951` |
| FreeType | 2.14.3 | FreeType License (FTL) | `freetype-2.14.3.tar.xz`, `.sig` | Werner Lemberg, `E306 7470 7856 409F F194 8010 BE6C 3AAC 63AD 8E3F` |
| HarfBuzz | 14.5.1 | MIT | `harfbuzz-14.5.1.tar.xz` | o SHA-256 que o GitHub mostra no anexo da release do projeto |
| FriBidi | 1.0.17 | LGPL 2.1+ | `fribidi-1.0.17.tar.xz` | o SHA-256 que o GitHub mostra no anexo da release do projeto |
| dav1d | 1.5.4 | BSD 2-Clause | `dav1d-1.5.4.tar.xz`, `.asc`, `.sha256` | a "VideoLAN Release Signing Key", `65F7 C6B4 206B D057 A7EB 7378 7180 713B E58D 1ADC`, e o `.sha256` publicado pelo projeto |
| libdisplay-info | 0.2.0 | MIT | `libdisplay-info-0.2.0.tar.xz`, `.sig` | Simon Ser, `34FF 9526 CFEF 0E97 A340 E2E4 0FDE 7BE0 E88F 5E48` |

O build do Windows usa ainda o zlib 1.3.1, do pacote `libz-mingw-w64-dev` (1.3.1+dfsg-1) do Ubuntu 24.04 (licença zlib, que não pede
os fontes; ficam nos arquivos do Ubuntu).

Para baixar e conferir (o `SHA256SUMS` também é um arquivo da release):

```bash
mkdir fontes && cd fontes
gh release download fontes-libmpv-0.41.0-ffmpeg-9.0.2 --repo Alcateia-DS/resonance-lgpl      # ou baixe os arquivos pela página da release
sha256sum -c --ignore-missing SHA256SUMS                         # no macOS: shasum -a 256 -c --ignore-missing SHA256SUMS
gpg --import ffmpeg-devel.asc && gpg --verify ffmpeg-9.0.2.tar.xz.asc ffmpeg-9.0.2.tar.xz   # as outras, com as chaves da tabela
```

### Como compilar

As três receitas leem a **pasta dos fontes** (a `fontes` acima: elas conferem o `SHA256SUMS` antes de começar) e gravam num **prefixo**.
O prefixo fica gravado dentro da biblioteca (o `configure` do FFmpeg vai no `avcodec_configuration()`): use um caminho neutro, como o das
releases do Resonance. A libplacebo é a única que a receita busca do git (`git clone` da tag `v7.360.1` e dos submódulos, com o commit
conferido): esse passo precisa de rede para o GitHub. O `libplacebo-7.360.1.tar.xz` da release é essa mesma tag com os cinco submódulos que
o build usa (glad, jinja, markupsafe, fast_float e Vulkan-Headers; o `demos/3rdparty/nuklear`, só das demos, que o build não compila, fica
de fora), para o código continuar à mão se o repositório dela sair do ar.

- **Linux (x86_64)**, num contêiner `ubuntu:22.04` (`--platform linux/amd64`, glibc 2.35), como root; a receita instala as ferramentas
  com `INSTALAR_DEPENDENCIAS=1` (o meson 1.12.1 vem do `pip`):
  `INSTALAR_DEPENDENCIAS=1 packaging/linux/build-libmpv-lgpl.sh "$PWD/fontes" /opt/libmpv-lgpl`
  Saída: `/opt/libmpv-lgpl/dist/` (o `libmpv.so.2`, o FFmpeg `libav*.so.*`, o `BUILDINFO.txt` e os avisos).
- **macOS (arm64, macOS 11 ou mais novo)**, com as Command Line Tools do Xcode, `meson`, `ninja`, `nasm` e `pkg-config`:
  `packaging/macos/build-libmpv-lgpl.sh "$PWD/fontes" /tmp/libmpv-lgpl-macos`
  Saída: `<prefixo>/lib/libmpv.2.dylib` e o `<prefixo>/BUILDINFO.txt`.
- **Windows (x86_64)**, compilado de forma cruzada num contêiner `ubuntu:24.04` com o mingw-w64:
  `apt-get install build-essential pkg-config meson ninja-build nasm python3 git curl ca-certificates xz-utils gcc-mingw-w64-x86-64-posix g++-mingw-w64-x86-64-posix binutils-mingw-w64-x86-64 mingw-w64-tools libz-mingw-w64-dev`
  e `packaging/windows/build-libmpv-lgpl.sh "$PWD/fontes" /opt/win64`
  Saída: `<prefixo>/bin/libmpv-2.dll` e o `<prefixo>/BUILDINFO.txt`.

Cada receita recusa o build que não saiu em modo LGPL (a licença gravada no FFmpeg, o `configure` sem `--enable-gpl`, `--enable-nonfree` e
`--enable-version3`, o `gpl : false` do mpv) e grava o `BUILDINFO` com a prova. Compare o seu com o `packaging/deps/BUILDINFO-<sistema>.txt`.
As receitas e os BUILDINFO são os que o `packaging/deps/SHA256SUMS` fixa (lá as receitas se chamam `build-libmpv-lgpl-<sistema>.sh`).

### Como trocar a biblioteca no Resonance

- **Windows:** o `libmpv-2.dll` fica ao lado do `resonance.exe` (por padrão, `%LOCALAPPDATA%\Programs\Resonance Nativo`).
- **Linux:** `/usr/lib/resonance/libmpv.so.2` e, na mesma pasta, o FFmpeg (`libavcodec.so.63` e as outras); no AppImage, `usr/lib/resonance`.
- **macOS:** `Resonance Nativo.app/Contents/Frameworks/libmpv.2.dylib`. A troca invalida a assinatura do aplicativo: assine de novo
  (`codesign --force --deep --sign - "Resonance Nativo.app"`).
- Para só experimentar, a variável de ambiente `RESONANCE_LIBMPV=<caminho do arquivo>` faz o Resonance abrir esse libmpv.

O texto da licença e os avisos de cada biblioteca também vão no pacote do Resonance, no arquivo `THIRD_PARTY_NOTICES.txt`.

### Licença e contato

Os arquivos das releases são software livre de terceiros, cada um sob a licença do seu autor (a tabela acima e `packaging/deps/licenses/`).
As receitas e este texto são da Alcateia DS e estão aqui para que qualquer pessoa reproduza e modifique o libmpv e o FFmpeg que
acompanham o Resonance. Se algo aqui estiver fora do ar ou incompleto, peça o código pela página de contato do site:
<https://theresonances.com/contato>.

## English

[Resonance](https://theresonances.com), Alcateia DS's media center for Windows, Linux and macOS, plays video with **libmpv** (mpv 0.41.0)
and **FFmpeg** 9.0.2. Both libraries are free software under the **GNU Lesser General Public License, version 2.1 or later** (LGPL
2.1+). libmpv ships in the Resonance package as a separate file loaded at run time (on Windows and macOS with FFmpeg built into it; on
Linux with FFmpeg in files next to it): you can replace those files with a version of your own, and Resonance's `LICENSE` grants that,
plus the reverse engineering needed to debug the replacement (LGPL section 6).

This repository has everything the LGPL asks for so you can do that and check what Resonance ships:

- the **exact source code** of the packages built into the binaries: the [`fontes-libmpv-0.41.0-ffmpeg-9.0.2`](https://github.com/Alcateia-DS/resonance-lgpl/releases/tag/fontes-libmpv-0.41.0-ffmpeg-9.0.2) release, with its
  `SHA256SUMS` and the authors' signatures;
- the **build recipes** for the three systems (`packaging/linux`, `packaging/macos`, `packaging/windows`), the very ones that built
  Resonance's binaries;
- the **BUILDINFO** of each system (`packaging/deps/BUILDINFO-*.txt`): FFmpeg's `configure` line, mpv's meson summary, the system
  libraries each file uses and the SHA-256 of every source;
- the **license texts** (`packaging/deps/licenses/`).

No GPL part is included: FFmpeg is configured without `--enable-gpl`, `--enable-nonfree` and `--enable-version3` (the license recorded in
it is "LGPL version 2.1 or later"), and mpv is built with `-Dgpl=false`.

### The source code

All of it is in the `fontes-libmpv-0.41.0-ffmpeg-9.0.2` release; `SHA256SUMS` (also here, at the root) has the SHA-256 of every package.

| Package | Version | License | Files | Where it comes from and how to check |
|---|---|---|---|---|
| mpv | 0.41.0 | LGPL 2.1+ (`-Dgpl=false`) | `mpv-0.41.0.tar.gz` | GitHub's tarball of tag `v0.41.0` (signed and verified by GitHub); the commit inside the tarball (`gzip -dc mpv-0.41.0.tar.gz \| git get-tar-commit-id`) is `41f6a645068483470267271e1d09966ca3b9f413` |
| FFmpeg | 9.0.2 | LGPL 2.1+ | `ffmpeg-9.0.2.tar.xz`, `.asc`, `ffmpeg-devel.asc` | the "FFmpeg release signing key", fingerprint `FCF9 86EA 15E6 E293 A564 4F10 B432 2F04 D676 58D8` (the one on ffmpeg.org) |
| libplacebo | 7.360.1 | LGPL 2.1+ | `libplacebo-7.360.1.tar.xz`, `libplacebo-7.360.1.submodules.txt` | tag `v7.360.1` (commit `cee9b076f2c63104ccfd497fa79c39a867293ec4`, signed and verified by GitHub) with the five submodules the build uses inside; all six, with commits, are in `.submodules.txt` |
| libass | 0.17.5 | ISC | `libass-0.17.5.tar.xz`, `.asc` | Oneric, `DDAF C19E 46B2 AD2D 6B26 F843 97A0 8E0C FFD7 0951` |
| FreeType | 2.14.3 | FreeType License (FTL) | `freetype-2.14.3.tar.xz`, `.sig` | Werner Lemberg, `E306 7470 7856 409F F194 8010 BE6C 3AAC 63AD 8E3F` |
| HarfBuzz | 14.5.1 | MIT | `harfbuzz-14.5.1.tar.xz` | the SHA-256 GitHub shows on the project's release asset |
| FriBidi | 1.0.17 | LGPL 2.1+ | `fribidi-1.0.17.tar.xz` | the SHA-256 GitHub shows on the project's release asset |
| dav1d | 1.5.4 | BSD 2-Clause | `dav1d-1.5.4.tar.xz`, `.asc`, `.sha256` | the "VideoLAN Release Signing Key", `65F7 C6B4 206B D057 A7EB 7378 7180 713B E58D 1ADC`, and the `.sha256` the project publishes |
| libdisplay-info | 0.2.0 | MIT | `libdisplay-info-0.2.0.tar.xz`, `.sig` | Simon Ser, `34FF 9526 CFEF 0E97 A340 E2E4 0FDE 7BE0 E88F 5E48` |

The Windows build also uses zlib 1.3.1, from Ubuntu 24.04's `libz-mingw-w64-dev` package (1.3.1+dfsg-1; zlib license, which does not ask
for the source; it is in Ubuntu's archive).

To download and check (`SHA256SUMS` is also a file of the release):

```bash
mkdir fontes && cd fontes
gh release download fontes-libmpv-0.41.0-ffmpeg-9.0.2 --repo Alcateia-DS/resonance-lgpl      # or download the files from the release page
sha256sum -c --ignore-missing SHA256SUMS                         # macOS: shasum -a 256 -c --ignore-missing SHA256SUMS
gpg --import ffmpeg-devel.asc && gpg --verify ffmpeg-9.0.2.tar.xz.asc ffmpeg-9.0.2.tar.xz   # the others, with the keys in the table
```

### Building

Each recipe takes the folder with the sources (`fontes` above; the recipes check `SHA256SUMS` before starting) and an output prefix. The
prefix is recorded inside the library (FFmpeg's `configure` line ends up in `avcodec_configuration()`): pick a neutral path, like the
one Resonance's releases used. Only libplacebo is fetched from git by the recipes (`git clone` of tag `v7.360.1` and its submodules, with the
commit pinned), so that step needs network access to GitHub; `libplacebo-7.360.1.tar.xz` in the release is that same tag with the five
submodules the build uses (glad, jinja, markupsafe, fast_float and Vulkan-Headers; `demos/3rdparty/nuklear`, used only by the demos, which
the build does not compile, is left out), so the code stays available if its repository goes offline.

- **Linux (x86_64)**, in an `ubuntu:22.04` container (`--platform linux/amd64`, glibc 2.35), as root; the recipe installs the tools with
  `INSTALAR_DEPENDENCIAS=1` (meson 1.12.1 comes from `pip`):
  `INSTALAR_DEPENDENCIAS=1 packaging/linux/build-libmpv-lgpl.sh "$PWD/fontes" /opt/libmpv-lgpl`
  Output: `/opt/libmpv-lgpl/dist/` (`libmpv.so.2`, FFmpeg's `libav*.so.*`, `BUILDINFO.txt` and the notices).
- **macOS (arm64, macOS 11 or newer)**, with the Xcode Command Line Tools, `meson`, `ninja`, `nasm` and `pkg-config`:
  `packaging/macos/build-libmpv-lgpl.sh "$PWD/fontes" /tmp/libmpv-lgpl-macos`
  Output: `<prefix>/lib/libmpv.2.dylib` and `<prefix>/BUILDINFO.txt`.
- **Windows (x86_64)**, cross-compiled in an `ubuntu:24.04` container with mingw-w64:
  `apt-get install build-essential pkg-config meson ninja-build nasm python3 git curl ca-certificates xz-utils gcc-mingw-w64-x86-64-posix g++-mingw-w64-x86-64-posix binutils-mingw-w64-x86-64 mingw-w64-tools libz-mingw-w64-dev`
  and `packaging/windows/build-libmpv-lgpl.sh "$PWD/fontes" /opt/win64`
  Output: `<prefix>/bin/libmpv-2.dll` and `<prefix>/BUILDINFO.txt`.

Each recipe refuses a build that did not come out LGPL (the license recorded in FFmpeg, a `configure` without `--enable-gpl`,
`--enable-nonfree` and `--enable-version3`, mpv's `gpl : false`) and writes a `BUILDINFO` as proof. Compare yours with
`packaging/deps/BUILDINFO-<system>.txt`. The recipes and the BUILDINFO files are the ones `packaging/deps/SHA256SUMS` pins (there the
recipes are called `build-libmpv-lgpl-<system>.sh`).

### Replacing the library in Resonance

- **Windows:** `libmpv-2.dll` sits next to `resonance.exe` (by default `%LOCALAPPDATA%\Programs\Resonance Nativo`).
- **Linux:** `/usr/lib/resonance/libmpv.so.2` and, in the same folder, FFmpeg (`libavcodec.so.63` and the others); in the AppImage,
  `usr/lib/resonance`.
- **macOS:** `Resonance Nativo.app/Contents/Frameworks/libmpv.2.dylib`. Replacing it invalidates the app's signature: sign it again
  (`codesign --force --deep --sign - "Resonance Nativo.app"`).
- To just try a build, set `RESONANCE_LIBMPV=<path to the file>` and Resonance opens that libmpv.

The license text and each library's notices also ship in the Resonance package, in `THIRD_PARTY_NOTICES.txt`.

### License and contact

The files in the releases are third-party free software, each under its author's license (the table above and
`packaging/deps/licenses/`). The recipes and this text are Alcateia DS's, published so anyone can reproduce and modify the libmpv and
FFmpeg that ship with Resonance. If anything here is offline or incomplete, ask for the code through the site's contact page:
<https://theresonances.com/contato>.
