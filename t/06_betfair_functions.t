#!/usr/bin/perl
use strict;
use warnings;
use Net::Ping;
use Term::ReadKey;
use Test::More;

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
  skip "these tests will not be performed", 1 unless $continue;
  # Create Object w/o attributes
  ok(my $bf = WWW::BetfairNG->new(),   'CREATE New $bf Object');
  # Try non-interactive login first
 SKIP: {
    $keyfile = '' unless (-e $certfile and -e $keyfile);
    skip "requires SSL certificate", 1 unless $keyfile;
    is($bf->ssl_cert($certfile), $certfile,                   "Set SSL cert file");
    is($bf->ssl_key($keyfile),   $keyfile,                    "Set SSL key file");
    ok($bf->login({username=>$username,password=>$password}), "Log in");
    ok($bf->logout(),                                         "Log out");
  }
  ok(my $logged_in = $bf->interactiveLogin({username=>$username,password=>$password}),
                                                              "Log in");
 SKIP: {
    skip $bf->error, 1 unless $logged_in;
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
    for my $comp (0..@{$bf->response} - 1) {
      ok(exists $bf->response->[$comp]->{marketCount},        "marketCount");
      ok(exists $bf->response->[$comp]->{competitionRegion},  "competitionRegion");
      ok(exists $bf->response->[$comp]->{competition},        "competition");
      ok(exists $bf->response->[$comp]->{competition}->{id},  "competition{id}");
      ok(exists $bf->response->[$comp]->{competition}->{name},"competition{name}");
    }
    ok($bf->listCountries($params),                           "listCountries");
    for my $ctry (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$ctry]->{marketCount},        "marketCount");
      ok(exists $bf->response->[$ctry]->{countryCode},        "countryCode");
    }
    $params = {};
    ok($bf->listCurrentOrders($params),                       "listCurrentOrders");
    ok(exists $bf->response->{currentOrders},                 "currentOrders");
    ok(exists $bf->response->{moreAvailable},                 "moreAvailable");
    for my $order (0..@{$bf->response->{currentOrders}}-1){
      my $record = $bf->response->{currentOrders}->[$order];
      ok(exists $record->{betId},          	              "betId");
      ok(exists $record->{marketId},       	              "marketId");
      ok(exists $record->{selectionId},    	              "selectionId");
      ok(exists $record->{handicap},       	              "handicap");
      ok(exists $record->{priceSize},      	              "priceSize");
      ok(exists $record->{bspLiability},   	              "bspLiability");
      ok(exists $record->{side},           	              "side");
      ok(exists $record->{status},         	              "status");
      ok(exists $record->{persistenceType},	              "persistenceType");
      ok(exists $record->{orderType},      	              "orderType");
      ok(exists $record->{placedDate},     	              "placedDate");
      ok(exists $record->{matchedDate},    	              "matchedDate");
    }
    $params->{betStatus} = 'SETTLED';
    ok($bf->listClearedOrders($params),                       "listClearedOrders");
    # No 'required' fields in ClearedOrdersSummary
    ok(exists $bf->response->{clearedOrders},                 "clearedOrders");
    ok(exists $bf->response->{moreAvailable},                 "moreAvailable");
    $params = {filter => {}};
    ok($bf->listEvents($params),                              "listEvents");
    for my $event (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$event]->{marketCount},       "marketCount");
      ok(exists $bf->response->[$event]->{event},             "event");
      ok(exists $bf->response->[$event]->{event}->{name},     "event{name}");
      ok(exists $bf->response->[$event]->{event}->{id},       "event{id}");
      ok(exists $bf->response->[$event]->{event}->{timezone}, "event{timezone}");
      ok(exists $bf->response->[$event]->{event}->{openDate}, "event{openDate}");
    }
    $params = {filter => {}};
    ok($bf->listEventTypes($params),                           "listEventTypes");
    for my $type (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$type]->{marketCount},         "marketCount");
      ok(exists $bf->response->[$type]->{eventType},           "event");
      ok(exists $bf->response->[$type]->{eventType}->{name},   "event{name}");
      ok(exists $bf->response->[$type]->{eventType}->{id},     "event{id}");
    }
    my $start_time = time() + 86400; # one day from now in seconds
    my ($sec,$min,$hour,$mday,$month,$year) = gmtime($start_time);
    $year  += 1900;
    $month += 1;
    my $start_time_ISO = sprintf("%04s", $year )."-";
    $start_time_ISO   .= sprintf("%02s", $month)."-";
    $start_time_ISO   .= sprintf("%02s", $mday )."T";
    $start_time_ISO   .= sprintf("%02s", $hour ).":";
    $start_time_ISO   .= sprintf("%02s", $min  )."Z";
    $params = {filter => {}};
    $params->{maxResults}       = '1';
    $params->{marketProjection} = ['RUNNER_DESCRIPTION'];
    $params->{marketStartTime}  = {from => $start_time_ISO};
    ok($bf->listMarketCatalogue($params),                      "listMarketCatalogue");
    for my $market (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$market]->{marketName},        "marketName");
      ok(exists $bf->response->[$market]->{marketId},          "marketId");
      ok(exists $bf->response->[$market]->{totalMatched},      "totalMatched");
      ok(exists $bf->response->[$market]->{runners},           "runners");
      foreach my $runner (@{$bf->response->[$market]->{runners}}) {
	ok(exists $runner->{selectionId},                      "selectionId");
	ok(exists $runner->{runnerName},                       "runnerName");
	ok(exists $runner->{handicap},                         "handicap");
	ok(exists $runner->{sortPriority},                     "sortPriority");
      }
    }
    # Concentrate on the first and last runners in the first market
    my $market_id     = $bf->response->[0]->{marketId};
    my $runners       = $bf->response->[0]->{runners};
    $params = {marketIds => [$market_id]};
    $params->{priceProjection} = {priceData => ['EX_BEST_OFFERS']};
    ok($bf->listMarketBook($params),                            "listMarketBook");
    for my $market (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$market]->{marketId},             "marketId");
      ok(exists $bf->response->[$market]->{isMarketDataDelayed},  "isMarketDataDelayed");
      ok(exists $bf->response->[$market]->{status},               "status");
      ok(exists $bf->response->[$market]->{betDelay},             "betDelay");
      ok(exists $bf->response->[$market]->{bspReconciled},        "bspReconciled");
      ok(exists $bf->response->[$market]->{complete},             "complete");
      ok(exists $bf->response->[$market]->{inplay},               "inplay");
      ok(exists $bf->response->[$market]->{numberOfWinners},      "numberOfWinners");
      ok(exists $bf->response->[$market]->{numberOfRunners},      "numberOfRunners");
      ok(exists $bf->response->[$market]->{numberOfActiveRunners},"numberOfActiveRunners");
#     ok(exists $bf->response->[$market]->{lastMatchTime},        "lastMatchTime");
      ok(exists $bf->response->[$market]->{totalMatched},         "totalMatched");
      ok(exists $bf->response->[$market]->{totalAvailable},       "totalAvailable");
      ok(exists $bf->response->[$market]->{crossMatching},        "crossMatching");
      ok(exists $bf->response->[$market]->{runnersVoidable},      "runnersVoidable");
      ok(exists $bf->response->[$market]->{version},              "version");
      ok(exists $bf->response->[$market]->{runners},              "runners");
      foreach my $runner (@{$bf->response->[$market]->{runners}}) {
	ok(exists $runner->{selectionId},                      "selectionId");
	ok(exists $runner->{handicap},                         "handicap");
	ok(exists $runner->{status},                           "status");
#       ok(exists $runner->{adjustmentFactor},                 "adjustmentFactor");
	ok(exists $runner->{ex},                               "exchange");
     }
    }
    $params = {};
    $params->{marketId} = $market_id;
    my $instructions = [];
    for (0,-1) {
      my $instruction = {handicap => '0', side => 'BACK', orderType => 'LIMIT'};
      $instruction->{limitOrder} = {size => '0.01', persistenceType => 'LAPSE'};
      $instruction->{selectionId} = qq/$runners->[$_]->{selectionId}/;
      $instruction->{limitOrder}->{price} = "1000";
      push @$instructions, $instruction;
    }
    $params->{instructions} = $instructions;
    ok(!$bf->placeOrders($params),                              "placeOrders");
    is($bf->error,         'ACCESS_DENIED',                     "Access Denied");
    $params = {};
    $params->{marketId} = $market_id;
    ok(!$bf->cancelOrders($params),                             "cancelOrders");
    is($bf->error,         'ACCESS_DENIED',                     "Access Denied");
    $params->{instructions} = [{betId => '6666666', newPrice => '500'}];
    ok(!$bf->replaceOrders($params),                            "replaceOrders");
    is($bf->error,         'ACCESS_DENIED',                     "Access Denied");
    $params->{instructions} = [{betId => '6666666', newPersistenceType => 'LAPSE'}];
    ok(!$bf->updateOrders($params),                             "updateOrders");
    is($bf->error,         'ACCESS_DENIED',                     "Access Denied");
    $params = {marketIds => [$market_id]};
    ok($bf->listMarketProfitAndLoss($params),                   "listMarketProfitAndLoss");
    for my $market (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$market]->{marketId},           "marketId");
      ok(exists $bf->response->[$market]->{profitAndLosses},    "profitAndLosses");
      foreach my $runner (@{$bf->response->[$market]->{profitAndLosses}}) {
	ok(exists $runner->{selectionId},                       "selectionId");
	ok(exists $runner->{ifWin},                             "ifWin");
      }
    }
    $params = {filter => {}};
    ok($bf->listMarketTypes($params),                           "listMarketTypes");
    for my $type (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$type]->{marketType},           "marketType");
      ok(exists $bf->response->[$type]->{marketCount},          "marketCount");
    }
    $params->{granularity} = 'DAYS';
    ok($bf->listTimeRanges($params),                            "listTimeRanges");
    for my $range (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$range]->{timeRange},           "timeRange");
      ok(exists $bf->response->[$range]->{marketCount},         "marketCount");
      ok(exists $bf->response->[$range]->{timeRange}->{from},   "timeRange{from}");
      ok(exists $bf->response->[$range]->{timeRange}->{to},     "timeRange{to}");
    }
    $params = {filter => {}};
    ok($bf->listVenues($params),                                "listVenues");
    for my $venue (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$venue]->{venue},               "venue");
      ok(exists $bf->response->[$venue]->{marketCount},         "marketCount");
    }
    # createDeveloperAppKeys NOT TESTED
    ok($bf->getAccountDetails(),                                "getAccountDetails");
    ok(exists $bf->response->{currencyCode},    		"currencyCode");
    ok(exists $bf->response->{firstName},     		        "firstName");
    ok(exists $bf->response->{lastName},      		        "lastName");
    ok(exists $bf->response->{localeCode},    		        "localeCode");
    ok(exists $bf->response->{region},        		        "region");
    ok(exists $bf->response->{timezone},      		        "timezone");
    ok(exists $bf->response->{discountRate},  		        "discountRate");
    ok(exists $bf->response->{pointsBalance}, 		        "pointsBalance");
    ok($bf->getAccountFunds(),                                  "getAccountFunds");
    ok(exists $bf->response->{availableToBetBalance},  		"availableToBetBalance");
    ok(exists $bf->response->{exposure},               		"exposure");
    ok(exists $bf->response->{retainedCommission},     		"retainedCommission");
    ok(exists $bf->response->{exposureLimit},          		"exposureLimit");
    ok(exists $bf->response->{discountRate},           		"discountRate");
    ok(exists $bf->response->{pointsBalance},          		"pointsBalance");
    $params = {recordCount => 5};
    ok($bf->getAccountStatement($params),                       "getAccountStatement");
    ok(exists $bf->response->{moreAvailable},                   "moreAvailable");
    ok(exists $bf->response->{accountStatement},                "accountStatement");
    for my $item (@{$bf->response->{accountStatement}}) {
      ok(exists $item->{refId},                                 "refId");
      ok(exists $item->{itemDate},       	  	        "itemDate");
      ok(exists $item->{amount},         	  	        "amount");
      ok(exists $item->{balance},        	  	        "balance");
      ok(exists $item->{itemClass},      	  	        "itemClass");
      ok(exists $item->{itemClassData},  	  	        "itemClassData");
      ok(exists $item->{legacyData},     	  	        "legacyData");
    }
    $params = {fromCurrency => 'GBP'};
    ok($bf->listCurrencyRates($params),                         "listCurrencyRates");
    for my $item (0..@{$bf->response}-1) {
      ok(exists $bf->response->[$item]->{currencyCode},         "currencyCode");
      ok(exists $bf->response->[$item]->{rate},                 "rate");
    }
    ok($bf->logout(),                                           "Log out");
  }
}

done_testing();
