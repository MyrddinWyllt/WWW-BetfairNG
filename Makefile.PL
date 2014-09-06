use 5.10.1;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME           => 'WWW::BetfairNG',
    AUTHOR         => 'Myrddin Wyllt <myrddinwyllt@tiscali.co.uk>',
    VERSION_FROM   => 'lib/WWW/BetfairNG.pm',
    ABSTRACT_FROM  => 'lib/WWW/BetfairNG.pm',
    LICENSE        => "perl_5",
    PREREQ_PM      => {
	'JSON'          => 2.59,
	'REST::Client'  => 271,
        'Term::ReadKey' => 2.31,
    },
);
