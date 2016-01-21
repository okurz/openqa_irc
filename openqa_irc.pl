#!/usr/bin/perl
use warnings;
use strict;

package MyBot;
use base qw( Bot::BasicBot );
use Mojo::UserAgent;


my $ua = Mojo::UserAgent->new;
my $host = 'openqa.suse.de';

# the 'said' callback gets called when someone says something in
# earshot of the bot.
sub said {
    my ($self, $message) = @_;
    return unless ($message->{body} =~ /^!/);
    if ($message->{body} =~ /\bperl\b/) {
        return "I hear Ruby is better than perl..";
    }
    elsif ($message->{body} =~ /help/) {
        return help();
    }
    elsif ($message->{body} =~ /\blast builds\b/) {
        my $products = $ua->get($host)->res->dom->find('h2 > a');
        my $products_text = $products->map('text')->join("\n");
        # TODO replace hardcoded by search
        my $product = qr/Server/;
        return "Give me a product to search for. The following products are available: $products_text\n" unless $product;
        # TODO assuming there is only one (discarding all others)
        my $build = $products->first($product);
        return "Could not find $product. The following products are available: $products_text\n" unless $build;
        my $last_builds = $ua->get($host.$build->{href})->res->dom->find('.col-md-4 > h4 a');
        return "Last builds for $product: ".$last_builds->map('text')->join(", ");
    }
    #elsif ($message->{body} =~ /\blast review\b/) {
    #    my $products = $ua->get($host)->res->dom->find('h2 > a');
    #}
}

sub tick {
    my ($self) = @_;
    $self->notice(
        channel => '#openqa-test',
        body => "openQA bot ready for service, msg me 'help' for details"
    );
    return 600;
}

# help text for the bot
sub help { "Help for 'openQA-bot'
    Write a message in a room I am in starting with '!' as a prefix.
    Try the following commands: perl, last builds" }

MyBot->new(
    server => 'irc.suse.de',
    ssl => 1,
    port => 6697,
    channels => [ '#openqa-test' ],
    nick => 'openqa',
)->run();
