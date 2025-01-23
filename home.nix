{ pkgs, ... }: {
  home = {
    stateVersion = "23.11";
    
    packages = with pkgs; [
      # your packages here
    ];
  };

  programs = {
    # your program configurations here
  };
}