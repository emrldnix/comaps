{
  lib,
  organicmaps,
  fetchurl,
  fetchFromGitea,
  boost,
  gtest,
  glm,
  gflags,
  imgui,
  jansson,
  python3,
  optipng,
  utf8cpp,
  nix-update-script,
}:
let
  joinPatches = x: map (patch: ./patches + "/./${patch}") x;

  mapRev = 250713;

  worldMap = fetchurl {
    url = "https://cdn.comaps.app/maps/${toString mapRev}/World.mwm";
    hash = "sha256-nHXc8O8Am4P2quR0KdS3qClWc+33hDLg6sG3Fch2okA=";
  };

  worldCoasts = fetchurl {
    url = "https://cdn.comaps.app/maps/${toString mapRev}/WorldCoasts.mwm";
    hash = "sha256-HOnu8rETA0DVrq1hpQc72oPJWiGmGM00KTLIWYTqlIo=";
  };
in
organicmaps.overrideAttrs (oldAttrs: rec {
  pname = "comaps";
  version = "2025.08.13-8";

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "comaps";
    repo = "comaps";
    tag = "v${version}";
    hash = "sha256-kvE3H+siV/8v4WgsG1Ifd4gMMwGLqz28oXf1hB9gQ2Q=";
    fetchSubmodules = true;
  };

  patches = joinPatches [
    "remove-lto.patch"
    "use-vendored-protobuf.patch"
  ];

  nativeBuildInputs = (builtins.filter (x: x != python3) oldAttrs.nativeBuildInputs or [ ]) ++ [
    (python3.withPackages (ps: with ps; [
      protobuf
    ]))
    optipng
  ];

  buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
    boost
    gtest
    gflags
    glm
    imgui

    (jansson.overrideAttrs (oa: {
      postFixup = (oa.postFixup or "") + ''
        substituteInPlace $dev/lib/cmake/jansson/janssonTargets-release.cmake \
          --replace-fail "\''${_IMPORT_PREFIX}" "$out"
      '';
    }))

    utf8cpp
  ];

  preConfigure = ''
    bash ./configure.sh --skip-map-download
  '';

  cmakeFlags = [
    (lib.cmakeBool "WITH_SYSTEM_PROVIDED_3PARTY" true)
  ];

  env = {
    NIX_CFLAGS_COMPILE = toString [
      "-I/build/source/3party/fast_double_parser/include"
    ];
    PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = "python";
  };

  postInstall = ''
    install -Dm644 ${worldMap} $out/share/comaps/data/World.mwm
    install -Dm644 ${worldCoasts} $out/share/comaps/data/WorldCoasts.mwm
    ln -s $out/bin/CoMaps $out/bin/comaps
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "-vr"
      "v(.*)"
    ];
  };

  meta = oldAttrs.meta // {
    description = "Community-led fork of Organic Maps";
    homepage = "https://comaps.app";
    changelog = "https://codeberg.org/comaps/comaps/releases/tag/v${version}";
    maintainers = [ lib.maintainers.ryand56 ];
    mainProgram = "comaps";
  };
})
