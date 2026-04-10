{ bash, lib, makeWrapper, rustPlatform }:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  sourceTree = lib.cleanSourceWith {
    src = ../.;
    filter = path: type:
      let
        base = baseNameOf path;
        excluded = [
          ".beads"
          ".git"
          ".github"
          ".ntm"
          "agent_baseline"
          "result"
          "sample_beads_db_files"
          "scripts"
          "skills"
          "temp_test"
          "temp_test_2"
        ];
      in
      !(builtins.elem base excluded
        || lib.hasSuffix ".png" base
        || lib.hasSuffix ".webp" base);
  };
  builtBinary = manifest.binary.upstreamName or manifest.binary.name;
  aliasOutputs = manifest.binary.aliases or [ ];
  licenseMap = {
    "MIT" = lib.licenses.mit;
    "Apache-2.0" = lib.licenses.asl20;
  };
  resolvedLicense =
    if builtins.hasAttr manifest.meta.licenseSpdx licenseMap
    then licenseMap.${manifest.meta.licenseSpdx}
    else lib.licenses.unfree;
  aliasScripts = lib.concatMapStrings
    (
      alias:
      ''
        cat > "$out/bin/${alias}" <<EOF
#!${lib.getExe bash}
exec "$out/bin/${manifest.binary.name}" "\$@"
EOF
        chmod +x "$out/bin/${alias}"
      ''
    )
    aliasOutputs;
in
rustPlatform.buildRustPackage {
  pname = manifest.binary.name;
  version = manifest.package.version;
  src = sourceTree;
  sourceRoot = "source/upstream";

  cargoLock = {
    lockFile = ../upstream/Cargo.lock;
    allowBuiltinFetchGit = true;
  };

  cargoBuildFlags =
    (lib.optionals (manifest.binary ? package) [ "-p" manifest.binary.package ])
    ++ [ "--bin=${builtBinary}" ];

  nativeBuildInputs = [ makeWrapper ];
  doCheck = false;

  env = {
    RUSTC_BOOTSTRAP = "1";
    VERGEN_IDEMPOTENT = "1";
    VERGEN_GIT_SHA = manifest.source.rev;
    VERGEN_GIT_DIRTY = "false";
  };

  postInstall = ''
    if [ "${builtBinary}" != "${manifest.binary.name}" ]; then
      mv "$out/bin/${builtBinary}" "$out/bin/${manifest.binary.name}"
    fi
    ${aliasScripts}
  '';

  meta = with lib; {
    description = manifest.meta.description;
    homepage = manifest.meta.homepage;
    license = resolvedLicense;
    mainProgram = manifest.binary.name;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
