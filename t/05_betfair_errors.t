#!/usr/bin/perl
use strict;
use warnings;
use Net::Ping;
use Test::More tests => 25;

# Load Module
BEGIN { use_ok('WWW::BetfairNG') };


my $p = Net::Ping->new();
print STDERR "The world has NOT ended.\n" if $p->ping('www.bbc.co.uk');
$p->close();


$SIG{ALRM} = \&timed_out;
eval {
    alarm (5);
    my $buf = <>;
    alarm(0);           # Cancel the pending alarm if user responds.
};
if ($@ =~ /GOT TIRED OF WAITING/) {
    print "Timed out. Proceeding with default\n";
  }

sub timed_out {
    die "GOT TIRED OF WAITING";
  }



# Create Object w/o attributes
ok(my $bf = WWW::BetfairNG->new(),   'CREATE New $bf Object');
# Test interactiveLogin
is($bf->interactiveLogin(), 0,               "InteractiveLogin fails with no parameters");
is($bf->error(), "Username and Password Required", "No parameter error message OK");
is($bf->interactiveLogin(username=>'username', password=>'password'), 0,
                                             "InteractiveLogin fails with no hashref");
is($bf->error(), "Parameters must be a hash ref or anonymous hash",
                                             "Not a hash error message OK");
is($bf->interactiveLogin({username=>'username', passwurd=>'password'}), 0,
                                             "InteractiveLogin fails with bad keys");
is($bf->error(), "Username and Password Required",
                                             "Bad key error message OK");
is($bf->interactiveLogin({username=>'username'}), 0,
                                             "InteractiveLogin fails with missing keys");
is($bf->error(), "Username and Password Required",
                                             "Missing key error message OK");
is($bf->interactiveLogin({username=>'username', password=>'password'}), 0,
                                             "InteractiveLogin fails with no app key");
is($bf->error(), "INPUT_VALIDATION_ERROR",
                                              "No app key error message OK");
is($bf->app_key( 'appkey'), 'appkey',         "SET app_key");
is($bf->interactiveLogin({username=>'username', password=>'password'}), 0,
                                              "InteractiveLogin fails with bad password");
is($bf->error(), "INVALID_USERNAME_OR_PASSWORD",
                                              "Bad password error message OK");


# Test login
is($bf->login(), 0,                                "Login fails with no parameters");
is($bf->error(), "Username and Password Required", "No parameter error message OK");
is($bf->login(username=>'username', password=>'password'), 0,
                                                   "Login fails with no hashref");
is($bf->error(), "Parameters must be a hash ref or anonymous hash",
                                                   "Not a hash error message OK");
is($bf->login({username=>'username', passwurd=>'password'}), 0,
                                                   "Login fails with bad keys");
is($bf->error(), "Username and Password Required",
                                                   "Bad key error message OK");
is($bf->login({username=>'username'}), 0,
                                                   "Login fails with missing keys");
is($bf->error(), "Username and Password Required",
                                                   "Missing key error message OK");
is($bf->login({username=>'username', password=>'password'}), 0,
                                                   "Login fails with no cert");
is($bf->error(), "SSL Client Certificate Required",
                                                   "No cert error message OK");
