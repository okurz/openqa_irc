use Test::More;
use Test::Bot::BasicBot::Pluggable;

my $bot = Test::Bot::BasicBot::Pluggable->new();

ok(my $ob = $bot->load("OpenQA"), 'load openqa module');
is($bot->tell_direct("!perl"), "I hear Ruby is better than perl..", "simple messages work");

done_testing();
