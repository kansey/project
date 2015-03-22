package Project;
use Mojo::Base 'Mojolicious';
use utf8;
use lib qw(lib/dbix-struct/lib);
use SQL::Abstract;
use DBI;
use DBD::Pg;
# This method will run once at server start
sub startup {
	my $self = shift;
    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
    #Plugin by sending mail message
    $self->plugin(mail =>{
    	from =>'project-ssh@mail.ru',
    	type => 'text/html'});
    # Router
    my $r = $self->routes;
    $r->get('/')->to('users#aut');
    $r->get('/show')->to('meny#show_command');
    $r->post('/meny')->to('users#meny');
    $r->post('/reg')->to('users#registration');
    $r->post('/create_email')->to('users#create_email');
    $r->post('/mail')->to('users#sendmail');
    $r->post('/cpu')->to('meny#handling_cpu');
    $r->post('/vsz')->to('meny#handling_vsz');
    $r->post('/rss')->to('meny#handling_rss');
    $r->post('/graph')->to('meny#create_graph');
    
    my $dbh = DBI->connect('dbi:Pg:dbname=project', 'postgres', '123456',{
    	PrintError => 0,
        AutoCommit => 1,
        RaiseError => 1
    }) or die(DBI->errstr);

    $self->helper(db =>sub{return $dbh;});
    $self->helper(sql=>sub{return my $sql=SQL::Abstract->new;});
=pod
check_forms
type:helper
takes:data with values fields form
return:scarlar var witn values undef or 1
=cut     
    $self->helper(check_forms =>sub{
    	my @data_form=@_;
    	my $check=1;
    	#for check to not empty value
    	@data_form=map{
    		if ($_ eq ''){
    			$check=undef; 
		}
	    }@data_form;
	    return $check;
    });
}
1;
