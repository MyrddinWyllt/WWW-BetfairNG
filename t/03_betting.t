#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 3;

# Tests of betting methods NOT requiring internet connection
# ==========================================================

# Load Module
BEGIN { use_ok('WWW::BetfairNG') };
# Create Object w/o attributes
my $bf = new_ok('WWW::BetfairNG');
# Check all betting methods exist
my @methods = qw/
		  listCompetitions
		  listCountries
		  listCurrentOrders
		  listClearedOrders
		  listEvents
		  listEventTypes
		  listMarketBook
		  listMarketCatalogue
		  listMarketProfitAndLoss
		  listMarketTypes
		  listTimeRanges
		  listVenues
		  placeOrders
		  cancelOrders
		  replaceOrders
		  updateOrders/;
can_ok('WWW::BetfairNG', @methods);
