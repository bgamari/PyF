{ pkgs ? import ./nixpkgs.nix {} }:
with pkgs;
rec {
  inherit pkgs;

  # Explicit list of used files. Else there is always too much and
  # cache is invalidated.
  sources = lib.sourceByRegex ./.  [
    "PyF\.cabal$"
    ".*\.hs$"
    ".*\.md$"
    ".*\.golden$"
    "src"
    "app"
    "src/PyF"
    "src/PyF/Internal"
    "test"
    "test/failureCases"
    "test/golden"
    "LICENSE"
  ];

  pyfBuilder = hPkgs: haskell.lib.buildFromSdist (hPkgs.callCabal2nixWithOptions "PyF" sources "-fdev" {});

  pyf_86 = pyfBuilder haskell.packages.ghc865;
  pyf_88 = pyfBuilder haskell.packages.ghc883;
  pyf_810 = pyfBuilder (haskell.packages.ghc8101.override {
    overrides = self: super: with haskell.lib; {
      th-expand-syns = doJailbreak super.th-expand-syns;
    };
  });

  pyf = pyf_88;

  # Run hlint on the codebase
  hlint = runCommand "hlint-krank" {
    nativeBuildInputs = [haskellPackages.hlint];
  }
  ''
  cd ${sources}
  hlint .
  mkdir $out
  '';

  # Run ormolu on the codebase
  # Fails if there is something to format
  ormolu = runCommand "ormolu-krank" {
    nativeBuildInputs = [haskellPackages.ormolu];
  }
  ''
  cd ${sources}
  ormolu --mode check $(find -name '*.hs')
  mkdir $out
  '';

  hlint-fix = mkShell {
    nativeBuildInputs = [haskellPackages.hlint git haskellPackages.apply-refact];
    shellHook = ''
      for file in $(git ls-files | grep '\.hs$')
      do
        hlint  --refactor --refactor-options='-i' $file
      done
      exit 0
    '';
  };

  ormolu-fix = mkShell {
    nativeBuildInputs = [haskellPackages.ormolu git];
    shellHook = ''
      ormolu --mode inplace $(git ls-files | grep '\.hs$')
      exit 0
    '';
  };
}
