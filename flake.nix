{
  description = "nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager }:
  let
    configuration = { pkgs, config, ... }: {

      nixpkgs.config.allowUnfree = true;

      users.users."volkan.altan" = {
				name = "volkan.altan";
				home = "/Users/volkan.altan";
			};

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
          pkgs.csvtk
          pkgs.apacheKafka
          pkgs.kcat
          pkgs.mkalias
          # Langs
          pkgs.go          
          pkgs.gh
          # Lang tools
          pkgs.pyenv
          #
          pkgs.jq
          # Load test tools
          pkgs.jmeter
          pkgs.k6
          # Containers
          pkgs.kubectx
          pkgs.kubie
          pkgs.kubectl
          # Tools
          pkgs.k9s
          # Editors          
          pkgs.neovim
          pkgs.tmux
          # zsh
          pkgs.oh-my-zsh
          pkgs.zsh-syntax-highlighting
          pkgs.zsh-autosuggestions
          pkgs.zsh-completions
          pkgs.thefuck
          pkgs.fzf
          pkgs.fd
          # 
          pkgs.git
          # Network
          pkgs.htop
          pkgs.inetutils

          pkgs.openssl
          pkgs.pkg-config
          pkgs.rdkafka
          pkgs.nodejs_23
        ];

      homebrew = {
        enable = true;
        brews = [
          "mas"
          "redis"
          "watch"
        ];
        casks = [
          "ghostty"
          "docker"
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
          "ollama"          
        ];
        onActivation.cleanup = "zap";
      };

      launchd.user.agents = {
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
        discord = {
          serviceConfig = {
            ProgramArguments = [
              "/Applications/Discord.app/Contents/MacOS/Discord"
            ];
            RunAtLoad = true;
            KeepAlive = false;
            StandardOutPath = "/tmp/discord.log";
            StandardErrorPath = "/tmp/discord.error.log";
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

	  # Hot corners
      system.defaults.dock = {
        # wvous-tl-corner = 2;  # Top left corner
        # wvous-tr-corner = 13;  # Top right corner
        # wvous-bl-corner = 4;  # Bottom left corner
        wvous-tr-corner = 13;
        wvous-br-corner = 14;  # Bottom right corner
        # Numbers correspond to actions:
        # 2: Mission Control
        # 3: Application Windows
        # 4: Desktop
        # 5: Start Screen Saver
        # 6: Disable Screen Saver
        # 7: Dashboard
        # 10: Put Display to Sleep
        # 11: Launchpad
        # 12: Notification Center
        # 13: Lock screen 
        # 13: Quick note
      };

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      security.pam.enableSudoTouchIdAuth = true;

      # ZSH Configuration
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        promptInit = ""; # Clear this to avoid conflict
          
        interactiveShellInit = ''
          export HISTFILE="$HOME/.zsh_history"
          export HISTSIZE=10000000
          export SAVEHIST=10000000
          setopt EXTENDED_HISTORY
          setopt SHARE_HISTORY
          setopt HIST_IGNORE_DUPS

          # FZF configuration
          export FZF_DEFAULT_COMMAND='fd --type f'
          export FZF_DEFAULT_OPTS='--height 40% --border'
          
          if [ -n "$(command -v fzf)" ]; then
            source ${pkgs.fzf}/share/fzf/completion.zsh
            source ${pkgs.fzf}/share/fzf/key-bindings.zsh
          fi

          plugins=(git thefuck kubectl kubectx fzf redis-cli)

          # Load Oh My Zsh if it exists
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

      environment.shells = with pkgs; [ zsh ];
      environment.variables = {
        ZSH = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
        ZSH_THEME = "robbyrussell";
        PKG_CONFIG_PATH = "${pkgs.rdkafka}/lib/pkgconfig";
      };
    };
  in
  {
    # Build darwin flake using:
    darwinConfigurations."volkansmpro" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "volkan.altan";
          };
        }
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users."volkan.altan" = import ./home.nix;
          };
        }        
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."volkansmpro".pkgs;
  };
}