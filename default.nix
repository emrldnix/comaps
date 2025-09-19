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
  joinPatches = x: map (patch: ./patches + "/./${patch}.patch") x;

  mapRev = 250822;

  worldMap = fetchurl {
    url = "https://cdn-fi-1.comaps.app/maps/${toString mapRev}/World.mwm";
    hash = "sha256-OksUAix8yw0WQiJUwfMrjOCd/OwuRjdCOUjjGpnG2S8=";
  };

  worldCoasts = fetchurl {
    url = "https://cdn-fi-1.comaps.app/maps/${toString mapRev}/WorldCoasts.mwm";
    hash = "sha256-1OvKZJ3T/YJu6t/qTYliIVkwsT8toBSqGHUpDEk9i2k=";
  };
in
organicmaps.overrideAttrs (oldAttrs: rec {
  pname = "comaps";
  version = "2025.08.31-15";

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "comaps";
    repo = "comaps";
    tag = "v${version}";
    hash = "sha256-uRShcyMevNb/UE5+l8UabiGSr9TccVWp5xVoqI7+Oh8=";
    fetchSubmodules = true;
  };

  patches = joinPatches [
    "remove-lto"
    "use-vendored-protobuf"

    "fix-editor-tests"
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
    jansson
    utf8cpp
  ];

  postPatch = ''
    patchShebangs 3party/boost/tools/build/src/engine/build.sh
    install -Dm644 ${worldMap} data/World.mwm
    install -Dm644 ${worldCoasts} data/WorldCoasts.mwm
  '';

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
