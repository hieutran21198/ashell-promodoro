{
  description = "Promodoro plugin for ashell — a small CLI pomodoro timer designed to feed an ashell custom module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;

      snowfall = {
        namespace = "ashell-promodoro";
        meta = {
          name = "ashell-promodoro";
          title = "Ashell Promodoro Plugin";
        };
      };

      alias.packages.default = "promodoro";
    };
}
