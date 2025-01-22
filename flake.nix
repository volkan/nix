{
  description = "nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew }:
  let
    configuration = { pkgs, config, ... }: {

      nixpkgs.config.allowUnfree = true;

      # Add Rosetta installation script
      system.activationScripts.extraActivation.text = ''
        # Install Rosetta 2 if not already installed
        if ! pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto > /dev/null 2>&1; then
          echo "Installing Rosetta 2..."
          softwareupdate --install-rosetta --agree-to-license
        fi
      '';

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [
          pkgs.mkalias
          pkgs.neovim
          pkgs.tmux
          pkgs.oh-my-zsh
          pkgs.zsh-syntax-highlighting
          pkgs.zsh-autosuggestions
          pkgs.zsh-completions
          pkgs.git
        ];

      homebrew = {
        enable = true;
        brews = [
          "mas"
        ];
        casks = [
          "ghostty"
          "hammerspoon"
          "iina"
          "the-unarchiver"
          "textmate"
          "visual-studio-code"
          "clipy"
          "discord"
          "rectangle"
          "spotify"
          "google-chrome"
          "vlc"
          "cyberduck"
          "telegram"
        ];

        onActivation.cleanup = "zap";
      };

      launchd.user.agents = {
        clipy = {
          serviceConfig = {
            ProgramArguments = [
              "/Applications/Clipy.app/Contents/MacOS/Clipy"
            ];
            RunAtLoad = true;
            KeepAlive = true;
            StandardOutPath = "/tmp/clipy.log";
            StandardErrorPath = "/tmp/clipy.error.log";
          };
        };
        rectangle = {
          serviceConfig = {
            ProgramArguments = [
              "/Applications/Rectangle.app/Contents/MacOS/Rectangle"
            ];
            RunAtLoad = true;
            KeepAlive = true;
            StandardOutPath = "/tmp/rectangle.log";
            StandardErrorPath = "/tmp/rectangle.error.log";
          };
        };
      };         

      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
        pkgs.lib.mkForce ''
          # Set up applications.
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read -r src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';

      system.defaults = {
        dock.autohide  = true;
        dock.largesize = 64;
        dock.persistent-apps = [
          "/System/Applications/Mail.app"
          "/System/Applications/Calendar.app"
          "/Applications/Google Chrome.app"
        ];
        finder.FXPreferredViewStyle = "clmv";
        loginwindow.GuestEnabled  = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
        NSGlobalDomain.KeyRepeat = 2;
      };

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        promptInit = ""; # Clear this to avoid conflict
        
        # For adding plugins, you'll need to add them to environment.systemPackages
        variables = {
          ZSH_THEME = "robbyrussell";          
        };
      };

      environment.shells = with pkgs; [ zsh ];
      environment.variables = {
        ZSH = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
        ZSH_THEME = "robbyrussell";
      };

      # Configure zsh
      environment.extraInit = ''
        # Load Oh My Zsh
        if [ -e "$ZSH/oh-my-zsh.sh" ]; then
          source "$ZSH/oh-my-zsh.sh"
        fi

        # Load plugins
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh

        # Source local config if it exists
        if [ -f ~/.zshrc.local ]; then
          source ~/.zshrc.local
        fi
      '';

    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#osx-M61HQT3V2V
    darwinConfigurations."volkansmpro" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            # Apple Silicon Only
            enableRosetta = true;
            # User owning the Homebrew prefix
            user = "volkan.altan";
          };
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."volkansmpro".pkgs;
  };
}
