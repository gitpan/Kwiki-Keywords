use inc::Module::Install;

name('Kwiki-Keywords');
author('Brian Ingerson <ingy@cpan.org>');
abstract('Keywords for Kwiki');
license('perl');
version_from('lib/Kwiki/Keywords.pm');

requires(qw(
    perl 5.6.1
));

check_nmake();

&WriteAll();
