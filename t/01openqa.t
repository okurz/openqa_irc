use Test::More;
use Test::Bot::BasicBot::Pluggable;

my $bot = Test::Bot::BasicBot::Pluggable->new();

ok(my $ob = $bot->load('OpenQA'), 'load openqa module');
is($bot->tell_direct('perl'), 'I hear Ruby is better than perl..', 'simple messages work');
is($bot->tell_indirect('!perl'), 'I hear Ruby is better than perl..', 'exclamation mark tags are accepted');
isnt($bot->tell_indirect('perl'), 'I hear Ruby is better than perl..', 'only responds if addressed');

done_testing();
