#!/usr/bin/perl
# Author: Josh Holtrop
# Date: 2010-06-10
# Purpose: for fun, of course! Find a cribbage hand to make each score
# Algorithm is brute-force, going through every possible hand

use strict;
use warnings;


package Suit;

sub new
{
    my ($class, $ord) = @_;
    my $self = {'ord' => $ord};
    return bless($self, $class);
}

sub str
{
    my ($self) = @_;
    return ('S', 'C', 'H', 'D')[$self->{'ord'}];
}

sub eq
{
    my ($self, $other) = @_;
    return $self->{'ord'} == $other->{'ord'};
}


package Card;

sub new
{
    my ($class, $rank, $suit) = @_;
    my $self = {'rank' => $rank, 'suit' => $suit};
    return bless($self, $class);
}

sub value
{
    my ($self) = @_;
    return $self->{'rank'} >= 10 ? 10 : $self->{'rank'};
}

sub rank
{
    my ($self) = @_;
    return $self->{'rank'};
}

sub suit
{
    my ($self) = @_;
    return $self->{'suit'};
}

sub str
{
    my ($self) = @_;
    my $rank_str = ('A', 2, 3, 4, 5, 6, 7, 8, 9, 'T', 'J', 'Q', 'K')
        [$self->{'rank'} - 1];
    return $rank_str . $self->{'suit'}->str();
}

sub rankeq
{
    my ($self, $other) = @_;
    return $self->{'rank'} == $other->{'rank'};
}

sub suiteq
{
    my ($self, $other) = @_;
    return $self->{'suit'}->eq($other->{'suit'});
}

sub cmp($$)
{
    my ($self, $other) = @_;
    return $self->{'rank'} <=> $other->{'rank'};
}


package Hand;

sub new
{
    my ($class, $c1, $c2, $c3, $c4, $crib) = @_;
    my $self = {'cards' => [$c1, $c2, $c3, $c4], 'crib' => $crib};
    return bless($self, $class);
}

sub str
{
    my ($self) = @_;
    my $str = '[';
    foreach my $c (@{$self->{'cards'}})
    {
        $str .= $c->str();
        $str .= ', ';
    }
    $str .= 'crib: ';
    $str .= $self->{'crib'}->str();
    $str .= ']';
    return $str;
}

sub score
{
    my ($self) = @_;
    my $crib = $self->{'crib'};
    my @handcards = sort {$a->rank() <=> $b->rank()} (@{$self->{'cards'}});
    my @allcards = sort {$a->rank() <=> $b->rank()} (@handcards, $crib);
    my $score = 0;

    # Pairs
    my $lastrank = -1;
    my $same = 1;
    foreach my $c (@allcards)
    {
        if ($c->rank() == $lastrank)
        {
            $same++;
            $score += 2 * ($same - 1);
        }
        else
        {
            $same = 1;
        }
        $lastrank = $c->rank();
    }

    # Nobs
    foreach my $c (@handcards)
    {
        if ($c->rank() == 11 && $c->suit()->eq($crib->suit()))
        {
            $score++;
        }
    }

    # Suits
    my $suit = $handcards[0]->suit();
    my $same_suit = 0;
    foreach my $c (@handcards)
    {
        $same_suit++ if ($c->suit()->eq($suit));
    }
    if ($same_suit == 4)
    {
        $score += 4;
        $score++ if ($crib->suit()->eq($suit));
    }

    # Fifteens and Runs
    my $fifteen_and_run_score = sub {
        my @cards = @_;
        my $total = 0;
        my $score = 0;
        foreach my $c (@cards)
        {
            $total += $c->value();
        }
        $score += 2 if ($total == 15);
        if ($#cards >= 2)
        {
            my $firstrank = $cards[0]->rank();
            my $lastrank = $firstrank;
            my $is_run = 1;
            for my $i (1 .. $#cards)
            {
                unless ($cards[$i]->rank() - $firstrank == $i)
                {
                    $is_run = 0;
                }
                $lastrank = $cards[$i]->rank();
            }
            if ($is_run)
            {
                # make sure the run is not a sub-run of a longer run
                my $valid = 1;
                foreach my $c (@allcards)
                {
                    $valid = 0 if ($c->rank() == $firstrank - 1
                        || $c->rank() == $lastrank + 1);
                }
                $score += scalar(@cards) if ($valid);
            }
        }
        return $score;
    };
    my @slices = (
        [],
        [],
        [[0,1], [0,2], [0,3], [0,4], [1,2], [1,3], [1,4], [2,3], [2,4], [3,4]],
        [[0,1,2], [0,1,3], [0,1,4], [0,2,3], [0,2,4], [0,3,4],
            [1,2,3], [1,2,4], [1,3,4], [2,3,4]],
        [[0,1,2,3], [0,1,2,4], [0,1,3,4], [0,2,3,4], [1,2,3,4]],
        [[0,1,2,3,4]]
    );
    for my $count (2 .. 5)
    {
        foreach my $slice (@{$slices[$count]})
        {
            $score += &$fifteen_and_run_score(@allcards[@$slice]);
        }
    }

    return $score;
}


package main;

sub main
{
    my @deck;
    for my $rank (1 .. 13)
    {
        for my $suit (0 .. 3)
        {
            push(@deck, Card->new($rank, Suit->new($suit)));
        }
    }

    my %point_hands;
    my $num = 0;
    my $pct = 0;
    $| = 1;

    # iterate through all hands
    for my $c1 (0 .. 48)
    {
        for my $c2 ($c1+1 .. 49)
        {
            for my $c3 ($c2+1 .. 50)
            {
                for my $c4 ($c3+1 .. 51)
                {
                    for my $crib (0 .. 51)
                    {
                        next unless ($crib != $c1 && $crib != $c2
                            && $crib != $c3 && $crib != $c4);
                        my $hand = Hand->new(@deck[$c1, $c2, $c3, $c4, $crib]);
                        my $score = $hand->score();
                        $num++;
                        my $this_pct = int($num * 100 / 12994800);
                        if ($this_pct > $pct)
                        {
                            $pct = $this_pct;
                            print "\b\b\b\b\b${pct}%";
                        }
                        if (exists($point_hands{$score}))
                        {
                            $point_hands{$score}{'count'}++;
                        }
                        else
                        {
                            $point_hands{$score} = {
                                'hand' => $hand,
                                'count' => 1
                            };
                        }
                    }
                }
            }
        }
    }
    print "\b\b\b\b\b$num hands evaluated\n";

    foreach my $points (sort {$a <=> $b} keys %point_hands)
    {
        printf("%2d: %s (%d hands)\n",
            $points,
            $point_hands{$points}{'hand'}->str(),
            $point_hands{$points}{'count'});
    }
}

exit(&main());
