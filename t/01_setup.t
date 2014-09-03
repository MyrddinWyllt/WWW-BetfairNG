#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 52;

# Load Module
BEGIN { use_ok('WWW::BetfairNG') };
# Create Object w/o attributes
ok(my $bf = WWW::BetfairNG->new(),   'CREATE New $bf Object');
# Test typos don't autoload
eval {
  $bf->someCall();
};
like($@,
     qr/Can't locate object method "someCall" via package "WWW::BetfairNG" /,
                                     'CHECK typos do not autoload');
#  SET attributes
ok($bf->ssl_cert('certfile'),        'SET ssl_cert');
ok($bf->ssl_key( 'keyfile'),         'SET ssl_key');
ok($bf->app_key( 'appkey'),          'SET app_key');
ok($bf->session( 'session_token'),   'SET session');
# GET attributes
is($bf->ssl_cert(), 'certfile',      'GET ssl_cert');
is($bf->ssl_key(),  'keyfile',       'GET ssl_key');
is($bf->app_key(),  'appkey',        'GET app_key');
is($bf->session(),  'session_token', 'GET session');
# RE-GET attributes
is($bf->ssl_cert(), 'certfile',      'RE-GET ssl_cert');
is($bf->ssl_key(),  'keyfile',       'RE-GET ssl_key');
is($bf->app_key(),  'appkey',        'RE-GET app_key');
is($bf->session(),  'session_token', 'RE-GET session');
#UNSET attributes
is($bf->ssl_cert(undef),  undef,     'UNSET ssl_cert');
is($bf->ssl_key( undef),  undef,     'UNSET ssl_key');
is($bf->app_key( undef),  undef,     'UNSET app_key');
is($bf->session( undef),  undef,     'UNSET session');
#CHECK UNSET attributes
is($bf->ssl_cert(),  undef,          'CHECK UNSET ssl_cert');
is($bf->ssl_key(),   undef,          'CHECK UNSET ssl_key');
is($bf->app_key(),   undef,          'CHECK UNSET app_key');
is($bf->session(),   undef,          'CHECK UNSET session');
#Test Read-only attributes
is($bf->error(),               'OK', 'CHECK error OK');
is(ref($bf->response()),     'HASH', 'CHECK response exists');
is(keys %{$bf->response()},       0, 'CHECK response is empty');
is($bf->error('TEST_STRING'),  'OK', "CHECK error can't be SET");
is(keys %{$bf->response({t=>1})}, 0, "CHECK response can't be SET");
# Create object with bad attributes
$bf = undef;
is($bf, undef,                       "CHECK object Destroyed");
eval {
$bf = WWW::BetfairNG->new(ssl_cert => 'certfile2');
};
like($@,
     qr/Parameters must be a hash ref or anonymous hash /,
                                     'CHECK params must be hash');
is($bf, undef,                       "CHECK object NOT created");
eval {
$bf = WWW::BetfairNG->new({ssl_cert => 'certfile2',
                            ssl_key => 'keyfile2',
                           spurious => 'cardboard',
                            app_key => 'appkey2'});
};
like($@,
     qr/Unknown key value spurious in parameter hash/,
                                     'CHECK parameter namecheck');
is($bf, undef,                       "CHECK object NOT created");
# Create object with good attributes
eval {
$bf = WWW::BetfairNG->new({ssl_cert => 'certfile2',
                            ssl_key => 'keyfile2',
                            app_key => 'appkey2'});
};
is(ref($bf), 'WWW::BetfairNG',       "CHECK object created");
ok($bf->session('session_token2'),   'SET session');
# GET attributes
is($bf->ssl_cert(),'certfile2',      'GET ssl_cert');
is($bf->ssl_key(), 'keyfile2',       'GET ssl_key');
is($bf->app_key(), 'appkey2',        'GET app_key');
is($bf->session(), 'session_token2', 'GET session');
# RE-GET attributes
is($bf->ssl_cert(),'certfile2',      'RE-GET ssl_cert');
is($bf->ssl_key(), 'keyfile2',       'RE-GET ssl_key');
is($bf->app_key(), 'appkey2',        'RE-GET app_key');
is($bf->session(), 'session_token2', 'RE-GET session');
#UNSET attributes
is($bf->ssl_cert(undef),  undef,     'UNSET ssl_cert');
is($bf->ssl_key( undef),  undef,     'UNSET ssl_key');
is($bf->app_key( undef),  undef,     'UNSET app_key');
is($bf->session( undef),  undef,     'UNSET session');
#CHECK UNSET attributes
is($bf->ssl_cert(),  undef,          'CHECK UNSET ssl_cert');
is($bf->ssl_key(),   undef,          'CHECK UNSET ssl_key');
is($bf->app_key(),   undef,          'CHECK UNSET app_key');
is($bf->session(),   undef,          'CHECK UNSET session');
# Destroy the object
$bf = undef;
is($bf, undef,                       "CHECK object Destroyed");
