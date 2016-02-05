package Bot::BasicBot::Pluggable::Module::OpenQA;

use base 'Bot::BasicBot::Pluggable::Module';

use strict;
use warnings;

use Mojo::UserAgent;
use Carp qw(croak);


=pod
Ideas and TODOS what to implement and where to look for cool stuff:
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::WWWShorten
https://github.com/CloudBotIRC/CloudBot
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::Crontab
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::GitHub
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::Notes
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::Shutdown
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::Log
=cut


my $ua = Mojo::UserAgent->new;


sub init {
    my ($self) = @_;
    $self->config({
            notice_period_ready  => 600,
            host => 'openqa.opensuse.org',
        });

    $self->{tick_count} = 0;
}

sub told {
    my ($self, $mess) = @_;
    return unless ($mess->{body} =~ /^!/);
    if ($mess->{body} =~ /\bperl\b/) {
        return "I hear Ruby is better than perl..";
    }
    elsif ($mess->{body} =~ /help/) {
        return help();
    }
    elsif ($mess->{body} =~ /\blast builds\b/) {
        my $host = $self->get('host');
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
    #elsif ($mess->{body} =~ /\blast review\b/) {
    #    my $products = $ua->get($host)->res->dom->find('h2 > a');
    #}
}

sub tick {
    my ($self) = @_;
    croak if scalar @{$self->bot->{channels}} > 1;
    $self->{tick_count} += 5; # tick is called in 5 second interval

    if ($self->{tick_count} % ($self->get('notice_period_ready')) == 0) {
        $self->bot->notice(
            channel => $self->bot->{channels}->[0],  # we just select the first if multiple
            body => "openQA bot ready for service, msg me 'help' for details"
        );
    }
}

# help text for the bot
sub help { "Help for 'openQA-bot'
    Write a message in a room I am in starting with '!' as a prefix.
    Try the following commands: perl, last builds"
}

1;

