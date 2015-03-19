package Project::Controller::Meny;
use Mojo::Base 'Mojolicious::Controller';
use Email::Address;
use utf8;
use Encode ;
use Net::SSH::Perl;
use GD::Graph::lines;
use SQL::Abstract;
use DBI;
use DBD::Pg;
use Class::Date qw(now );
use Text::Password::Pronounceable::Harden;
# This action will render a template

=pod
generate_date
type:function
takes:scalar variable
return:object Class::Date containing the string with the date and time
=cut
sub generate_date {
	my $date=@_;
	my $now = now;
    return $date=$now->string ; 
}
=pod
check_port
type:function
takes:scalar variable 
return: scalar with the value 22(default port for ssh connect) or value of the variable $port
=cut
sub check_port {
	my $port=shift;
	$port eq ''?return 22:return $port;
}
=pod
get_id_user
type:function
takes:scalar variable with a value of a login form,helper db,helper sql
return:scalar variable with a string of sampling or error and undef 
=cut
sub get_id_user {
	my($login,$db,$sql)=@_;
    my $table='users';
    my($stmt,@bind)=$sql->select($table,[qw/id_user/],[{login=>$login}]);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
    my $id=$sth->fetchrow_array;
    return $id;
}
sub get_hash_host_data {
	return my %hash=(
		id_user  =>$_[0],
		host     =>$_[1],
		'"user"' =>$_[2],
		password =>$_[3],
		port     =>$_[4],
        time     =>$_[5],
		cmd      =>$_[6]
		);
}
=pod
create_host_query
type:function
takes:Ref to a hash with the values for the selection conditions,helper db,helper sql
return:An undef is returned if an error occurs or true if the string changed  
=cut
sub create_host_query {
	my($data,$db,$sql)=@_;
	my $table='host_data';
	my($stmt,@bind)=$sql->insert($table,$data);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
}
=pod
splitting
type:function
takes:string with the results of the command ps
return: array of ref to an array 
=cut
sub splitting {
	my $str=shift;
	my @split=split /\s/,$str;
	my @split_line;
	@split=grep{$_ if $_=~/(\d+?\.\d+?)|(\w+?)|(\d+?:\d+?)|(\?)/}@split;
	push @split_line,[@split];
	return @split_line;
}
=pod
gluing_elements
type:function
takes:list
return:array 
=cut
 sub gluing_elements {
 	my @gluing_data=@_;
 	for (my $i =0; $i<@gluing_data; $i++){
 		if ($i > 10){
 			$gluing_data[10]=$gluing_data[10].$gluing_data[$i];
 			delete $gluing_data[$i];
        }
 	} 	
	return @gluing_data;
}
=pod
get_id_con
type:function
takes:scalar variable with a value of a id connect and datetime,helper db,helper sql
return:scalar variable with a string of sampling or error and undef 
=cut
sub get_id_con{
	my($id,$date,$db,$sql)=@_;
    my $table='host_data';
    my($stmt,@bind)=$sql->select($table,[qw/id_conn/],[{id_user=>$id,time=>$date}]);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
    my $id_conn=$sth->fetchrow_array;
    return $id_conn;
}
sub get_hash_host_answer{
	return my %hash=(
		answer  =>$_[0],
		id_conn =>$_[1],
		id_user =>$_[2],
		time    =>$_[3]
	);
}
sub get_hash_id_user {return my %hash=(id_user=>$_[0]);}
=pod
create_host_answer
type:function
takes:Ref to a hash with the values for the selection conditions,helper db,helper sql
return:An undef is returned if an error occurs or true if the string changed
=cut
sub create_host_answer {
	my($data,$db,$sql)=@_;
	my $table='host_answer';
	my($stmt,@bind)=$sql->insert($table,$data);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
}
=pod
plotting 
type:function
takes:ref to the array with values cpu and vsz
return:object GD::Graph::lines is a graph png
=cut
sub plotting {
	my ($cpu_data,$vsz_data)=@_;
	my @data=($cpu_data,$vsz_data);
	my $mygraph = GD::Graph::lines->new(650,650);
	$mygraph->set(
		x_label=>'CPU',
		y_label=>'VSZ',
		title=>'Monitoring',
		line_types=>4,
		line_width=>2,
		dclrs=>['blue']
	)or warn $mygraph->error;
    my $myimage = $mygraph->plot(\@data) or die $mygraph->error;
    return $myimage;
}
=pod
save_the_file
type:function
takes:object GD::Graph::lines is a graph png
return:graphic PNG file format saved on the server side
=cut
sub save_the_file {
	my $image=shift;
	open(IMG, '>public/ico/graph.png') or die $!;
    print IMG $image->png;
    close IMG;
}
=pod
get_command
type:function
takes:Ref to a hash with the values for the selection conditions,helper db,helper sql
return:reference to an array containing a reference to an array for each row of data 
=cut
sub get_command {
	my($data,$db,$sql)=@_;
    my $table='host_data';
    my($stmt,@bind)=$sql->select($table,[qw/host port cmd time/],$data);
    my $cmd=$db->selectall_arrayref($stmt,{slice=>{}},@bind);
    return $cmd;
=pod
handling_cpu
type:controller method
takes:method name, data with form
return:html template and array ref in stash or message of incorrect data
=cut    
}
sub handling_cpu {
	my $self=shift;
	my $host=$self->param('host');
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $port=$self->param('port');
	my @prepared_data;
	my $get_check=$self->check_forms($host,$login,$password);
	my $login_cookie=$self->every_signed_cookie('login')->[0];
	my $date;
	utf8::encode($login);
	utf8::encode($password);
	utf8::encode($port);
	my($stdout, $stderr, $exit);
	   	if (!defined $get_check){
   		$self->render(text=>"Не заполнены обязательные поля,вернитесь на прошлую страницу!",status=>403);
	}
	$date=generate_date($date);
	$port=check_port($port);
	my $SSH=Net::SSH::Perl->new($host,debug=>1,protocol=>'1,2',port=>$port) || die $!;
	$SSH->login($login,$password);
	($stdout, $stderr, $exit) = $SSH->cmd('ps -aux --sort=-%cpu | head -16');
	my $sql=$self->sql;
    my $id_user=get_id_user($login_cookie,$self->db,$sql);
 	my %insertion_data_host=get_hash_host_data($id_user,$host,$login,$password,$port,$date,'ps -aux --sort=-%cpu | head -16');
    create_host_query(\%insertion_data_host,$self->db,$sql);
    my @stdout=split /\n/, $stdout;
    delete $stdout[0];
    @stdout=map{my @arr=splitting($_);push @prepared_data,@arr;}@stdout;
    @$_=gluing_elements(@$_)for @prepared_data;
    map{map{utf8::decode($_);}@$_;}@prepared_data;
    my $id_conn=get_id_con($id_user,$date,$self->db,$sql);
    $date=generate_date($date);
    my %insertion_data_answer=get_hash_host_answer($stdout,$id_conn,$id_user,$date);
    create_host_answer(\%insertion_data_answer,$self->db,$sql);
    $self->stash(split_stdout =>[@prepared_data]);  
}
=pod
handling_vsz
type:controller method
takes:method name, data with form
return:html template and array ref in stash or message of incorrect data
=cut 
sub handling_vsz {
	my $self=shift;
	my $host=$self->param('host');
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $port=$self->param('port');
	my @prepared_data;
	my $get_check=$self->check_forms($host,$login,$password);
	my $login_cookie=$self->every_signed_cookie('login')->[0];
	my $date;
	utf8::encode($login);
	utf8::encode($password);
	utf8::encode($port);
	my($stdout, $stderr, $exit);
   	if (!defined $get_check){
   		$self->render(text=>"Не заполнены обязательные поля,вернитесь на прошлую страницу!",status=>403);
	}
	$date=generate_date($date);
	$port=check_port($port);
    my $SSH=Net::SSH::Perl->new($host,debug=>1,protocol=>'1,2',port=>$port) || die $!;
	$SSH->login($login,$password);
 	($stdout, $stderr, $exit) = $SSH->cmd('ps -aux --sort=-vsz | head -16');
 	my $sql=$self->sql;
    my $id_user=get_id_user($login_cookie,$self->db,$sql);
 	my %insertion_data_host=get_hash_host_data($id_user,$host,$login,$password,$port,$date,'ps -aux --sort=-vsz | head -16');
    create_host_query(\%insertion_data_host,$self->db,$sql);
    my @stdout=split /\n/, $stdout;
    delete $stdout[0];
    @stdout=map{my @arr=splitting($_);push @prepared_data,@arr;}@stdout;
    @$_=gluing_elements(@$_)for @prepared_data;
    map{map{utf8::decode($_);}@$_;}@prepared_data;
    my $id_conn=get_id_con($id_user,$date,$self->db,$sql);
    $date=generate_date($date);
    my %insertion_data_answer=get_hash_host_answer($stdout,$id_conn,$id_user,$date);
    create_host_answer(\%insertion_data_answer,$self->db,$sql);
    $self->stash(split_stdout =>[@prepared_data]);
}
=pod
handling_rss
type:controller method
takes:method name, data with form
return:html template and array ref in stash or message of incorrect data
=cut 
sub handling_rss {
	my $self=shift;
	my $host=$self->param('host');
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $port=$self->param('port');
	my @prepared_data;
	my $get_check=$self->check_forms($host,$login,$password);
	my $login_cookie=$self->every_signed_cookie('login')->[0];
	my $date;
	utf8::encode($login);
	utf8::encode($password);
	utf8::encode($port);
	my($stdout, $stderr, $exit);
   	if (!defined $get_check){
   		$self->render(text=>"Не заполнены обязательные поля,вернитесь на прошлую страницу!",status=>403);
	}
	$date=generate_date($date);
	$port=check_port($port);
	my $SSH=Net::SSH::Perl->new($host,debug=>1,protocol=>'1,2',port=>$port) || die $!;
	$SSH->login($login,$password);
 	($stdout, $stderr, $exit) = $SSH->cmd('ps -aux --sort=-rss | head -16');
 	my $sql=$self->sql;
    my $id_user=get_id_user($login_cookie,$self->db,$sql);
 	my %insertion_data_host=get_hash_host_data($id_user,$host,$login,$password,$port,$date,'ps -aux --sort=-rss|head -16');
    create_host_query(\%insertion_data_host,$self->db,$sql);
    my @stdout=split /\n/, $stdout;
    delete $stdout[0];
    @stdout=map{my @arr=splitting($_);push @prepared_data,@arr;}@stdout;
    @$_=gluing_elements(@$_)for @prepared_data;
    map{map{utf8::decode($_);}@$_;}@prepared_data;
    my $id_conn=get_id_con($id_user,$date,$self->db,$sql);
    $date=generate_date($date);
    my %insertion_data_answer=get_hash_host_answer($stdout,$id_conn,$id_user,$date);
    create_host_answer(\%insertion_data_answer,$self->db,$sql);
    $self->stash(split_stdout =>[@prepared_data]);
}
=pod
create_graph
type:controller method
takes:method name, data with form
return:html template  or message of incorrect data
=cut 
sub create_graph {
	my $self=shift;
	my $host=$self->param('host');
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $port=$self->param('port');
	my $get_check=$self->check_forms($host,$login,$password);
	my $login_cookie=$self->every_signed_cookie('login')->[0];
	my $date;
	if (!defined $get_check){
   		$self->render(text=>"Не заполнены обязательные поля,вернитесь на прошлую страницу!",status=>403);
	}
	$date=generate_date($date);
	my @prepared_data;
	my($stdout, $stderr, $exit);
	my $login_cookie=$self->every_signed_cookie('login')->[0];
	utf8::encode($login);
	utf8::encode($password);
	utf8::encode($port);
	$port=check_port($port);
	my $SSH=Net::SSH::Perl->new($host,debug=>1,protocol=>'1,2',port=>$port) || die $!;
	$SSH->login($login,$password);
 	($stdout, $stderr, $exit) = $SSH->cmd('ps -aux --sort=-%cpu|head -16');
 	my $sql=$self->sql;
    my $id_user=get_id_user($login_cookie,$self->db,$sql);
 	my %insertion_data_host=get_hash_host_data($id_user,$host,$login,$password,$port,$date,'ps -aux --sort=-%cpu | head -16');
    create_host_query(\%insertion_data_host,$self->db,$sql);
    my @stdout=split /\n/, $stdout;
    delete $stdout[0];
    @stdout=map{my @arr=splitting($_);push @prepared_data,@arr;}@stdout;
    @$_=gluing_elements(@$_)for @prepared_data;
    map{map{utf8::decode($_);}@$_;}@prepared_data;
    my @cpu;
    map{
    	my @ref=@$_;
    	map{
    		my $i=$_;
    		if ($i==2){
    			push @cpu, $ref[$i];
		    }
	    }0..@ref;
    }@prepared_data;
    my @vsz;
    map{
    	my @ref=@$_;
    	map{
    		my $i=$_;
    		if ($i==4){
    			push @vsz, $ref[$i];
		    }
	    }0..@ref;
    }@prepared_data;
    @vsz=reverse @vsz;
    @cpu=sort {$a<=>$b}@cpu;
    my $graph=plotting(\@cpu,\@vsz);
    save_the_file($graph);
    my $id_conn=get_id_con($id_user,$date,$self->db,$sql);
    $date=generate_date($date);
    my %insertion_data_answer=get_hash_host_answer($stdout,$id_conn,$id_user,$date);
    create_host_answer(\%insertion_data_answer,$self->db,$sql);
}
=pod
show_command
type:controller method
takes:method name, data with form
return:html template and array ref in stash or message of incorrect data
=cut 
sub show_command {
	my $self=shift;
	my $login_cookie=$self->every_signed_cookie('login')->[0];
	my $sql=$self->sql;
    my $id_user=get_id_user($login_cookie,$self->db,$sql);
    my %select_show_cmd=get_hash_id_user($id_user);
    my $cmd=get_command(\%select_show_cmd,$self->db,$sql);
    #$self->render(text => "@$cmd", status => 403);
    $self->stash(cmd =>$cmd);
}
1;