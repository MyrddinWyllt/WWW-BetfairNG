#!/usr/bin/perl
use strict;
use warnings;
use Net::Ping;
use Term::ReadKey;
use Test::More tests => 50;

# Load Module
BEGIN { use_ok('WWW::BetfairNG') };

# Check if we can use the internet
my $continue = 1;
print STDERR <<EOF


============================================================================
NOTE:  These tests require a connection to the internet and will communicate
with the online gambling site 'Betfair'. Answer 'N' within 10 seconds if you
DO NOT wish to perform these tests.
============================================================================

EOF
;
print STDERR "Connect to internet? [Y/n]: ";
ReadMode 'cbreak';
my $key = ReadKey(10);
ReadMode 'normal';
unless ($key) {
  $key = 'Y';
}
print STDERR uc($key)."\n\n";
$continue = 0 if $key =~ m/^[nN]/;
# Check for connection even if we get permission
if ($continue){
  my $p = Net::Ping->new();
  $continue = 0 unless $p->ping('www.bbc.co.uk');
  $p->close();
}

SKIP: {
  skip "these tests will not be performed", 49 unless $continue;
  # Create Object w/o attributes
  ok(my $bf = WWW::BetfairNG->new(),   'CREATE New $bf Object');
  my %methods = (
  listCompetitions         => ['MarketFilter'],
  listCountries            => ['MarketFilter'],
  listCurrentOrders        => [],
  listClearedOrders        => ['BetStatus'],
  listEvents               => ['MarketFilter'],
  listEventTypes           => ['MarketFilter'],
  listMarketBook           => ['MarketIds'],
  listMarketCatalogue      => ['MarketFilter', 'MaxResults'],
  listMarketProfitAndLoss  => ['MarketIds'],
  listMarketTypes          => ['MarketFilter'],
  listTimeRanges           => ['MarketFilter', 'TimeGranularity'],
  listVenues               => ['MarketFilter'],
  placeOrders              => ['MarketId', 'PlaceInstructions'],
  cancelOrders             => [],
  replaceOrders            => ['MarketId', 'ReplaceInstructions'],
  updateOrders             => ['MarketId', 'UpdateInstructions'],
  createDeveloperAppKeys   => ['AppName'],
  getAccountDetails        => [],
  getAccountFunds          => [],
  getDeveloperAppKeys      => [],
  getAccountStatement      => [],
  listCurrencyRates        => [],
  navigationMenu           => [],
  );
  my %param_data = (
  MarketFilter        => {
			  name   => 'filter',
			  value  => {},
			  errstr => 'Market Filter is Required'
			 },
  BetStatus           => {
			  name   => 'betStatus',
			  value  => 'SETTLED',
			  errstr => 'Bet Status is Required'
			 },
  MarketIds           => {
			  name   => 'marketIds',
			  value  => ['1.111111'],
			  errstr => 'Market Ids are Required'
			 },
  MaxResults          => {
			  name   => 'maxResults',
			  value  => '1',
			  errstr => 'maxResults is Required'
			 },
  TimeGranularity     => {
			  name   => 'granularity',
			  value  => 'DAYS',
			  errstr => 'Time Granularity is Required'
			 },
  MarketId            => {
			  name   => 'marketId',
			  value  => '1.111111',
			  errstr => 'Market Id is Required'
			 },
  PlaceInstructions   => {
			  name   => 'instructions',
			  value  => [
				     {
				      selectionId => "6666666",
				      handicap    => "0",
				      side        => "BACK",
				      orderType   => "LIMIT",
				      limitOrder  => {
						      size => "0.01",
						      price => "1000",
						      persistenceType => "LAPSE"
						     }
				     }
				    ],
			  errstr => 'Order Instructions are Required'
			 },
  ReplaceInstructions => {
			  name   => 'instructions',
			  value  => [
				     {
				      selectionId => "6666666",
				      newPrice    => "500"
				     }
				    ],
			  errstr => 'Replace Instructions are Required'
			 },
  UpdateInstructions  => {
			  name   => 'instructions',
			  value  => [
				     {
				      selectionId => "6666666",
		               newPersistenceType => "LAPSE"
				     }
				    ],
			  errstr => 'Update Instructions are Required'
			 },
  AppName             => {
			  name   => 'appName',
			  value  => 'App Name',
			  errstr => 'App Name is Required'
			 }
   );
  is($bf->session('session_token'), 'session_token', "Set session token");
  is($bf->app_key('app_key'),       'app_key',       "Set app key");
  foreach my $method (keys %methods) {
    my $params = {};
    foreach my $required_param (@{$methods{$method}}) {
      my $pkey = $param_data{$required_param}{name};
      my $pval = $param_data{$required_param}{value};
      $params->{$pkey} = $pval;
    }
    ok(!$bf->$method($params), "Call $method");
    if (grep {$_ eq $method} qw/listCountries placeOrders listEventTypes listVenues
			       listEvents listCurrentOrders listMarketBook
			       listMarketProfitAndLoss
			       listCompetitions listClearedOrders cancelOrders
			       listMarketTypes listTimeRanges listMarketCatalogue/) {
      like($bf->error, qr/^INVALID_/,      "Bad app key or session error message");
    }
    else {
      is($bf->error, "400 Bad Request", "bad request error message");
    }
  }
}
