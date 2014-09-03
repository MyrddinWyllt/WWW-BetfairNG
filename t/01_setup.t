#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 3;


BEGIN { use_ok('WWW::BetfairNG') };

ok(my $bf =WWW::BetfairNG->new());
ok($bf->ssl_cert('certfile'));
#      $bf->ssl_key(<path to ssl key file>);
#      $bf->app_key(<application key>);