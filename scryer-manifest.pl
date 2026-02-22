name("regexp").
% Optional. The file that will be imported when this package is used.
main_file("main.pl").
% The license of the package
license(name("Unlicense"), path("./UNLICENSE")).
% Optional
dependencies([
    % A git url to clone
    dependency("testing", git("https://github.com/bakaq/testing.pl.git"))
    % A git url to clone at a specific branch
  ]).