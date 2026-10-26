{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  gmp,
  zlib,
}:

let
  version = "3.2.3";

  # Release asset suffix and hash for each supported Nix system.
  dists = {
    x86_64-linux = {
      arch = "linux-x64";
      hash = "sha256-6CpLSX8fh5HuFx0GxFKTuhZDLkhdZF3dloi6+mzN5aU=";
    };
    aarch64-linux = {
      arch = "linux-arm64";
      hash = "sha256-zgz1Zs4r0d07T7zB0H+S1U/1f7PMbW+gco1Kct9GTAI=";
    };
    aarch64-darwin = {
      arch = "macos-arm64";
      hash = "sha256-/+hOjGeYdolKxn2iMGbOrh/UM+JEA4p8iEpMqLRpjrg=";
    };
  };

  dist =
    dists.${stdenv.hostPlatform.system}
      or (throw "koka: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "koka";
  inherit version;

  src = fetchurl {
    url = "https://github.com/koka-lang/koka/releases/download/v${version}/koka-v${version}-${dist.arch}.tar.gz";
    inherit (dist) hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gmp
    zlib
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;

  # Koka finds its libraries relative to the executable (../lib, ../share),
  # and it calls a C compiler at run time, so put the stdenv compiler on PATH.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin lib share $out/
    wrapProgram $out/bin/koka --prefix PATH : ${lib.makeBinPath [ stdenv.cc ]}
    runHook postInstall
  '';

  meta = {
    description = "Strongly typed functional language with effect types and handlers";
    homepage = "https://koka-lang.github.io";
    license = lib.licenses.asl20;
    mainProgram = "koka";
    platforms = builtins.attrNames dists;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
