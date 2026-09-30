{
  description = "Fountain skills adapted for NixOS hosts that manage their own software";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      # NixOS is the only supported target: this fork exists for hosts that
      # manage their own software, and the skills use Linux-only paths.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      # The skill tree, as a store path. Consumers add the `skills` directory
      # inside this output to their agent's skill search path. Each skill is a
      # plain directory holding SKILL.md, so no unpacking or generation is
      # needed.
      skills = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "fountain-skills";
          version = "1.23.0";

          src = ./skills;

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p "$out"
            # `src` is the skills directory itself, so it becomes $out/skills.
            cp -R "$src" "$out/skills"

            runHook postInstall
          '';

          meta = {
            description = "Fountain skills for podcast growth, adapted for NixOS";
            license = lib.licenses.mit;
            platforms = systems;
          };
        });

      # Software the skills expect to find on the machine. A NixOS host should
      # take these from its own configuration rather than from this output, but
      # exposing them documents the contract and makes a check possible.
      runtimeDeps = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          inherit (pkgs)
            ffmpeg
            imagemagick
            yt-dlp
            fontconfig
            python313
            ;
        });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.python313
              pkgs.ruff
              pkgs.nodejs_22
            ];
            shellHook = ''
              echo "fountain-skills-nix dev shell"
              echo "  ruff check .   # lint the bundled scripts"
              echo "  node scripts/format.sh --check"
            '';
          };
        });
    };
}