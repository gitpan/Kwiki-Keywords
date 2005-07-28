package Kwiki::Keywords;
use Kwiki::Plugin -Base;
use mixin 'Kwiki::Installer';

const class_id       => 'keywords';
const class_title    => 'Keywords';
const cgi_class      => 'Kwiki::CGI::Keywords';

field keywords_directory => '-init' =>
    '$self->plugin_directory . "/keywords"';
field pages_directory => '-init' =>
    '$self->plugin_directory . "/pages"';

our $VERSION = '0.12';

sub init {
    super;
    return unless $self->is_in_cgi;
    io($self->keywords_directory)->mkdir;
    io($self->pages_directory)->mkdir;
}

sub register {
    my $registry = shift;
    $registry->add(hook => 'page:store', post => 'add_automatic_keywords');
    $registry->add(action => 'keyword_display');
    $registry->add(action => 'keyword_add');
    $registry->add(action => 'keyword_del');
    $registry->add(action => 'keyword_list');
    $registry->add(widget => 'keywords',
                   template => 'keywords_widget.html',
                   show_for => 'display',
               );
    $registry->add(toolbar => 'keyword_list',
                   template => 'keyword_list_button.html'
               );
}

sub keyword_add {
    my $keywords = $self->cgi->keyword;
    my $page = $self->hub->pages->new_from_name($self->cgi->page_name);
    my $count = 1;
    for my $keyword (split /\s+/, $keywords) {
        next unless $keyword;
        die "'$keyword' contains illegal characters"
          unless $keyword =~ /^[\w\-]+$/;
        $self->add_keyword($page, $keyword);
        last if ++$count > 5;   # sanity limit
    }
    $self->redirect($page->uri);
}

sub keyword_del {
    my $keyword = $self->cgi->keyword;
    my $page = $self->hub->pages->new_from_name($self->cgi->page_name);
    $self->del_keyword($page, $keyword);
    $self->redirect($page->uri);
}

sub keyword_display {
    my $keyword = $self->cgi->keyword;
    my $pages = $self->get_pages_for_keyword($keyword);
    $self->render_screen(
        screen_title => "Pages with keyword $keyword",
        pages => $pages,
    )
}

sub keyword_list {
    my $keywords = $self->get_all_keywords;
    my $blog = $self->hub->have_plugin('blog');
    $self->template_process($self->screen_template,
        content_pane => 'keyword_list.html',
        screen_title => "All Keywords",
        keywords => $keywords,
        blog => $blog,
    ); 
}

sub get_all_keywords {
    my $io = io($self->keywords_directory);
    return [ 
        sort {lc($a) cmp lc($b)}
        grep {
           scalar(@{$self->get_pages_for_keyword($_)}) 
        } 
        map {
            $_->filename
        } $io->all
    ];
}

sub get_pages_for_keyword {
    my $keyword = shift;
    my $io = io($self->keywords_directory . "/$keyword");
    my $pages = $io->exists
      ? [ map { 
          $self->hub->pages->new_from_name($_->filename) 
      } grep $_, $io->all ]
      : [];
    return $pages;
}

sub keywords_for_page {
    my $page = $self->hub->pages->current->id;
    my $io = io($self->pages_directory . "/$page");
    my $keywords = $io->exists
      ? [ 
            map { $_->filename } sort {
                $b->mtime <=> $a->mtime or
                lc("$a") cmp lc("$b")
            } $io->all
        ]
      : [];
    return $keywords;
}

sub add_automatic_keywords {
    my $hook = pop;
    my $pages = $self; # we're running in the class with class id page
    $self = $self->hub->keywords; # move ourselves into this class
    $self->add_author_keyword;
}

sub add_author_keyword {
    my $author = $self->hub->users->current->name;
    my $page = $self->hub->pages->current;
    $self->add_keyword($page, $author) if $author;
}

sub add_keyword {
    my $page = shift;
    my $keyword = shift;
    my $id = $page->id;
    io($self->keywords_directory . "/$keyword/$id")->assert->touch;
    io($self->pages_directory . "/$id/$keyword")->assert->touch;
}

sub del_keyword {
    my $page = shift;
    my $keyword = shift;
    my $id = $page->id;
    io($self->keywords_directory . "/$keyword/$id")->unlink;
    io($self->pages_directory . "/$id/$keyword")->unlink;
}

package Kwiki::CGI::Keywords;
use Kwiki::CGI -Base;

cgi 'keyword';
cgi 'page_name';

package Kwiki::Keywords;

__DATA__

=head1 NAME

Kwiki::Keywords - Keywords for Kwiki

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

YAPC::NA

=head1 COPYRIGHT

Copyright (c) 2005. Brian Ingerson. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
__template/tt2/keywords_content.html__
<table class="keywords">
[% FOR page = pages %]
<tr>
<td class="page_name">
[% page.kwiki_link %]
</td>
<td class="edit_by">[% page.edit_by_link %]</td>
<td class="edit_time">[% page.edit_time %]</td>
</tr>
[% END %]
</table>
__template/tt2/keyword_list.html__
<ul class="keywords">
[% FOR keyword = keywords %]
<li class="keyword">
<a href="[% script_name %]?action=keyword_display;keyword=[% keyword %]">
[% keyword %]
</a>
[% IF blog %]
(<a href="[% script_name %]?action=blog_display;blog_name=[% keyword %]">as blog</a>)
[% END %]
</li>
[% END %]
</ul>
__template/tt2/keywords_widget.html__
<script>
function keyword_delete(checkbox) {
    checkbox.value = ''
    if (! confirm("Really Remove This Keyword?"))
        return false
    var myform = document.forms.keywords
    myform.elements['action'].value = 'keyword_del'
    myform.elements['keyword'].value = checkbox.name
    myform.submit()
    return true
}

function keyword_validate(myform) {
    var keyword = myform.elements['keyword'].value
    if (keyword == '') {
        alert("No Keyword Specified")
        return false
    }
    if (! keyword.match(/^[\w\-\ ]+$/)) {
        alert("Invalid Value for Keyword")
        return false
    }
    return true
}
</script>
[% keywords = hub.keywords.keywords_for_page %]
<div style="font-family: Helvetica, Arial, sans-serif; overflow: hidden;"
     id="keywords">
<h3 style="font-size: small; text-align: center; letter-spacing: .25em; padding-bottom: .25em;">KEYWORDS</h3>
<form name="keywords" method="POST" action="" onsubmit="return keyword_validate(this)">
[% IF keywords.size %]
[% FOREACH keyword = keywords %]
<div style="font-size: small; display:block; text-decoration: none; padding-bottom: .25em;">
<input
 type="checkbox"
 name="[% keyword %]"
 onclick="return keyword_delete(this);"
 checked
>&nbsp;<a
 href="[% script_name %]?action=keyword_display;keyword=[% keyword %]">[% keyword %]</a>
</div>
[% END %]
[% END %]
<input type="hidden" name="action" value="keyword_add" />
<input type="hidden" name="page_name" value="[% page_name %]" />
<input name="keyword" type="text" value="New Keywords" onclick="this.value = ''" size="12" />
</form>
</div>
__template/tt2/keyword_list_button.html__
<a href="[% script_name %]?action=keyword_list">
[% INCLUDE keywords_button_icon.html %]
</a>
__template/tt2/keywords_button_icon.html__
Keywords
