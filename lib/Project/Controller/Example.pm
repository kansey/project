package Project::Controller::Example;
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
sub welcome {
  my $self = shift;
  # Render template "example/welcome.html.ep" with message
  $self->render(msg => 'Welcome to the Mojolicious real-time web framework!');
}
sub check_forms {
	my @data_form=@_;
	my $check=1;
	#for check to not empty value  
	@data_form=map{
		if ($_ eq '') {
			$check=undef; 
		}
	}@data_form;
	return $check;
}
sub check_password {
	my $pas=shift;
	my $confirm=shift;
	my $check=1;
	if ($pas ne $confirm) {
		$check=undef;
	}
	return $check;
}
sub check_email {
	my $email=shift;
	my $check=1;
	my @addrs=Email::Address->parse($email);
	if (@addrs==0) {
		$check=undef;
	}
	return $check;
}
sub check_port {
	my $port=shift;
	$port eq ''?return 22:return $port;
}
sub splitting {
	my $str=shift;
	my @split=split /\s/,$str;
	my @split_line;
	@split=grep{$_ if $_=~/(\d+?\.\d+?)|(\w+?)|(\d+?:\d+?)|(\?)/}@split;
	push @split_line,[@split];
	return @split_line;
}
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
sub save_the_file {
	my $image=shift;
	open(IMG, '>public/ico/graph.png') or die $!;
    print IMG $image->png;
    close IMG;
}
sub generate_date {
	my $date=@_;
	my $now = now;
    return $date=$now->string ; 
}
sub get_hash_id_user {return my %hash=(id_user=>$_[0]);}
sub get_hash_user{return my %hash=(login=>$_[0],password=>$_[1]);}
sub get_hash_mail{return my %hash=(id_user=>$_[0],mail=>$_[1]);}
sub get_hash_select_id_con{return my %hash=(id_user=>$_[0],time=>$_[1]);}
sub get_hash_host_answer{
	return my %hash=(
		answer  =>$_[0],
		id_conn =>$_[1],
		id_user =>$_[2],
		time    =>$_[3]
	);
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
sub create_user {
	my($data,$db,$sql)=@_;
    my $table='users';
    my($stmt,@bind)=$sql->insert($table,$data);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
}
sub get_id_user {
	my($login,$db,$sql)=@_;
    my $table='users';
    my($stmt,@bind)=$sql->select($table,[qw/id_user/],[{login=>$login}]);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
    my $id=$sth->fetchrow_array;
    return $id;
}
sub get_id_con{
	my($id,$date,$db,$sql)=@_;
    my $table='host_data';
    my($stmt,@bind)=$sql->select($table,[qw/id_conn/],[{id_user=>$id,time=>$date}]);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
    my $id_conn=$sth->fetchrow_array;
    return $id_conn;
}
sub user_exists {
	my($data,$db,$sql)=@_;
    my $table='users';
    my($stmt,@bind)=$sql->select($table,[qw/id_user/],$data);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
    my $id=$sth->fetchrow_array;
    return (defined $id);
}
sub create_email_for_user{
	my($data,$db,$sql)=@_;
	my $table='email';
	my($stmt,@bind)=$sql->insert($table,$data);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
}
sub create_host_query {
	my($data,$db,$sql)=@_;
	my $table='host_data';
	my($stmt,@bind)=$sql->insert($table,$data);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
}
sub create_host_answer {
	my($data,$db,$sql)=@_;
	my $table='host_answer';
	my($stmt,@bind)=$sql->insert($table,$data);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
}
sub get_command {
	my($data,$db,$sql)=@_;
    my $table='host_data';
    my($stmt,@bind)=$sql->select($table,[qw/host port cmd time/],$data);
    my $cmd=$db->selectall_arrayref($stmt,{slice=>{}},@bind);
    return $cmd;
}
sub get_id_by_mail {
	my($email,$db,$sql)=@_;
    my $table='email';
    my($stmt,@bind)=$sql->select($table,[qw/id_user/],[{mail=>$email}]);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
    my $id=$sth->fetchrow_array;
    return $id;
}
sub generate_pas {
	my $pwgen=Text::Password::Pronounceable::Harden->new(min => 8,max => 12);
    my $pas=$pwgen->generate();
    return $pas;
}
sub update_pas {
	my ($id_user,$password,$db,$sql)=@_;
	my $table='users';
	my %fieldvals=(password=>"$password");
	my %where=(id_user=>"$id_user");
	my($stmt,@bind)=$sql->update($table,\%fieldvals,\%where);
	my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
}
=cut
sub aut {
	my $self=shift;
	if (my $cookie=$self->every_signed_cookie('login')->[0]){
		$self->render(template => 'example/meny');
    }else{
    	$self->render(template => 'example/aut');
    }
}

sub meny {
	my $self=shift;
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $get_check=check_forms($login,$password);
	if (!defined $get_check) {
		$self->render(text=>"Введены некорректные данные с формы,перейдите на страницу входа",status=>403);	
    }
    #my $cookie=$self->signed_cookie("$login");
    my $sql=$self->sql;
    my %insertion_data_user=get_hash_user($login,$password);
    my $id_user=user_exists(\%insertion_data_user,$self->db,$sql);
    if($id_user){
    	$self->signed_cookie(login =>$login,{expires => time + 2000});
        #$self->render(text => "$id_user", status => 403);
    }else{
    	$self->render(text =>'Неверное имя пользователя / пароль',status => 403);
    }
}

sub registration {
	my $self=shift;
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $confirm_pas=$self->param('confirm-pas');
	my $mail=$self->param('email');
	my $get_check=check_forms($login,$password,$confirm_pas,$mail);
	my $check_password=check_password($password,$confirm_pas);
	my $check_email=check_email($mail);
	if (!defined $get_check) {
		$self->render(text=>"Введены некорректные данные с формы,перейдите на страницу входа",status=>403);
	}elsif (!defined $check_password){
		$self->render(text=>"Пароли не совпадают,вернитесь на страницу регистрации!",status=>403);
	}elsif (!defined $check_email){
		$self->render(text=>"Введен неккоректный email,вернитесь на страницу регистрации!",status=>403);
	}
    my $sql=$self->sql;
    my %insertion_data_user=get_hash_user($login,$password);
    create_user(\%insertion_data_user,$self->db,$sql);
    my $id_user=get_id_user($login,$self->db,$sql);
    my %insertion_data_mail=get_hash_mail($id_user,$mail);
    create_email_for_user(\%insertion_data_mail,$self->db,$sql);
}

sub sendmail {
	my $self=shift;
	my $mail=$self->param('mail');
	my $check_email=check_email($mail);
	if (!defined $check_email) {
		$self->render(text=>"Введен неккоректный email!",status=>403);
	}
	my $sql=$self->sql;
    my $id_user=get_id_by_mail($mail,$self->db,$sql);
    my $password=generate_pas();
    update_pas($id_user,$password,$self->db,$sql);
    $self->mail(
		to =>"$mail",
        subject =>'Project SSH',
        data =>"Ваш пароль был изменен на $password"
    );
}

sub handling_cpu {
	my $self=shift;
	my $host=$self->param('host');
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $port=$self->param('port');
	my @prepared_data;
	my $get_check=check_forms($host,$login,$password);
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

sub handling_vsz {
	my $self=shift;
	my $host=$self->param('host');
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $port=$self->param('port');
	my @prepared_data;
	my $get_check=check_forms($host,$login,$password);
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
sub handling_rss {
	my $self=shift;
	my $host=$self->param('host');
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $port=$self->param('port');
	my @prepared_data;
	my $get_check=check_forms($host,$login,$password);
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

sub create_graph {
	my $self=shift;
	my $host=$self->param('host');
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $port=$self->param('port');
	my $get_check=check_forms($host,$login,$password);
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
=cut
1;