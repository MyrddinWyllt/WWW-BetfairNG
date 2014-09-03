#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;

# Load Module
BEGIN { use_ok('WWW::BetfairNG') };
# Create Object w/o attributes
ok(my $bf = WWW::BetfairNG->new(),   'CREATE New $bf Object');