#!/usr/bin/perl
use strict;
use warnings;
use Net::Ping;
use Term::ReadKey;
use Test::More tests => 34;

use Data::Dumper;  # LOSE THIS IN LIVE

my $username = '';
my $password = '';
my $certfile = '';
my $keyfile  = '';
my $app_key  = '';
my $params   = {};

# Load Module
BEGIN { use_ok('WWW::BetfairNG') };

# Check if we can use the internet
my $continue = 0;
print STDERR <<EOF


============================================================================
NOTE:  These tests require a connection to the internet and will communicate
with the online gambling site 'Betfair'. They also require login credentials
(username and password)  for an active, funded Betfair account. NO BETS WILL
BE PLACED, but  all  functionality  which does not involve placing live bets
will be tested. The default is NOT to run these tests; if you wish  them  to
run, enter 'Y' at the prompt within 20 seconds.
============================================================================

EOF
;
print STDERR "Perform these tests? [y/N]: ";
ReadMode 'cbreak';
my $key = ReadKey(20);
ReadMode 'normal';
unless ($key) {
  $key = 'N';
}
print STDERR uc($key)."\n\n";
$continue = 1 if $key =~ m/^[yY]/;
# Check for connection even if we get permission
if ($continue){
  my $p = Net::Ping->new();
  $continue = 0 unless $p->ping('www.bbc.co.uk');
  $p->close();
}
INPUT: {
  if ($continue) {
    print STDERR "Username: ";
    chomp($username = <STDIN>);
    unless ($username){
      $continue = 0;
      last INPUT;
    }
    ReadMode 'noecho';
    print STDERR "Password (will not echo): ";
    chomp($password = <STDIN>);
    print STDERR "\n";
    ReadMode 'normal';
    unless ($password){
      $continue = 0;
      last INPUT;
    }
    print STDERR "\nIf you wish to test SSL certificate login, please enter the path to\n";
    print STDERR "your certificate (.crt) and key (.key) files. (The certificate must\n";
    print STDERR "already be registered with  Betfair). If you leave this blank, only\n";
    print STDERR "non-certificate (interactive) login will be tested.\n\n";
    print STDERR "Path to SSL client cert file: ";
    chomp($certfile = <STDIN>);
    unless ($certfile){
      last INPUT;
    }
    print STDERR "Path to SSL client  key file: ";
    chomp($keyfile = <STDIN>);
  }
}

SKIP: {
  skip "these tests will not be performed", 33 unless $continue;
  # Create Object w/o attributes
  ok(my $bf = WWW::BetfairNG->new(),   'CREATE New $bf Object');
  # Try non-interactive login first
 SKIP: {
    $keyfile = '' unless (-e $certfile and -e $keyfile);
    skip "requires SSL certificate", 4 unless $keyfile;
    is($bf->ssl_cert($certfile), $certfile,                   "Set SSL cert file");
    is($bf->ssl_key($keyfile),   $keyfile,                    "Set SSL key file");
    ok($bf->login({username=>$username,password=>$password}), "Log in");
    ok($bf->logout(),                                         "Log out");
  }
  ok(my $logged_in = $bf->interactiveLogin({username=>$username,password=>$password}),
                                                              "Log in");
 SKIP: {
    skip $bf->error, 27 unless $logged_in;
    ok($bf->getDeveloperAppKeys(),                            "Get Keys");
    foreach my $version (@{$bf->response->[0]{appVersions}}) {
      if ($version->{delayData}) {
	$app_key = $version->{applicationKey};
      }
    }
    is($bf->app_key($app_key),      $app_key,                 "Set app key");
    ok($bf->keepAlive(),                                      "keepAlive");
    is($bf->response->{token},      $bf->session,             "Check session token");
    $params->{filter} = {};
    ok($bf->listCompetitions($params),                        "listCompetitions");
    ok(exists $bf->response->[0]->{marketCount},              "marketCount");
    ok(exists $bf->response->[0]->{competitionRegion},        "competitionRegion");
    ok(exists $bf->response->[0]->{competition},              "competition");
    ok(exists $bf->response->[0]->{competition}->{id},        "competition{id}");
    ok(exists $bf->response->[0]->{competition}->{name},      "competition{name}");
    ok($bf->listCountries($params),                           "listCountries");
    ok(exists $bf->response->[0]->{marketCount},              "marketCount");
    ok(exists $bf->response->[0]->{countryCode},              "countryCode");
    $params = {};
    ok($bf->listCurrentOrders($params),                       "listCurrentOrders");
    ok(exists $bf->response->{currentOrders},                 "currentOrders");
    ok(exists $bf->response->{moreAvailable},                 "moreAvailable");
    $params->{betStatus} = 'SETTLED';
    ok($bf->listClearedOrders($params),                       "listClearedOrders");
    ok(exists $bf->response->{clearedOrders},                 "clearedOrders");
    ok(exists $bf->response->{moreAvailable},                 "moreAvailable");
    $params = {filter => {}};
    ok($bf->listEvents($params),                              "listEvents");
    ok(exists $bf->response->[0]->{marketCount},              "marketCount");
    ok(exists $bf->response->[0]->{event},                    "event");
    ok(exists $bf->response->[0]->{event}->{name},            "event{name}");
    ok(exists $bf->response->[0]->{event}->{id},              "event{id}");
    ok(exists $bf->response->[0]->{event}->{timezone},        "event{timezone}");
    ok(exists $bf->response->[0]->{event}->{openDate},        "event{openDate}");









#    print STDERR Dumper($bf->response);
    ok($bf->logout(),                                           "Log out");
  }
}
