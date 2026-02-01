{
  config,
  inputs,
  pkgs,
  ...
}:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "ComradeJustin";
        email = "chinese2000ping@gmail.com";
      };
      init.defaultBranch = "main";
    };
  };

}
