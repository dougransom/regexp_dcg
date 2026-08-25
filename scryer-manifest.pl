name("regexp").
version("0.1.2.dev1").
% Main module entry point imported when using pkg(regexp)
main_file("regexp_dcg.pl").
% Package license
license(name("Unlicense"), path("./UNLICENSE")).
% Package dependencies
dependencies([
    dependency("testing", git("https://github.com/bakaq/testing.pl.git"))
]).