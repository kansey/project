package Project::Controller::Users;
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

sub get_hash_user{return my %hash=(login=>$_[0],password=>$_[1]);}
sub get_hash_mail{return my %hash=(id_user=>$_[0],mail=>$_[1]);}
=pod
user_exists
type:function
takes:Ref to a hash with the values for the selection conditions,helper db,helper sql
return:scalar variable with the value of the id  
=cut
sub user_exists {
    my($data,$db,$sql)=@_;
    my $table='users';
    my($stmt,@bind)=$sql->select($table,[qw/id_user/],$data);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
    my $id=$sth->fetchrow_array;
    return (defined $id);
}
=pod
check_password 
type:function
takes:scalar variables with the value of the password and confirm it with the form 
return:scalar variable with the value 1 or undef  
=cut
sub check_password {
	my $pas=shift;
	my $confirm=shift;
	my $check=1;
	if ($pas ne $confirm) {
	   $check=undef;
	}
	return $check;
}
=pod
check_email 
type:function
takes:scalar variable with a value of email form
return:scalar variable with the value 1 or undef  
=cut
sub check_email {
	my $email=shift;
	my $check=1;
	my @addrs=Email::Address->parse($email);
	
	if (@addrs==0){
	   $check=undef;
	}
	return $check;
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
=pod
insertions 
type:function
takes:scalar var with value name table,ref to a hash with values fields in table,helper db,helper sql
return:An undef is returned if an error occurs or true if the string changed
=cut
sub insertions {
	my($table,$fieldvals,$db,$sql)=@_;
	my($stmt,@bind)=$sql->insert($table,$fieldvals);
	my $sth =$db->prepare($stmt);
	$sth->execute(@bind);
}
=pod
get_id_by_mail  
type:function
takes:scalar variable with a value of a email form,helper db,helper sql
return:scalar variable with a string of sampling or error and undef 
=cut
sub get_id_by_mail {
    my($email,$db,$sql)=@_;
    my $table='email';
    my($stmt,@bind)=$sql->select($table,[qw/id_user/],[{mail=>$email}]);
    my $sth =$db->prepare($stmt);
    $sth->execute(@bind);
    my $id=$sth->fetchrow_array;
    return $id;
}
=pod
update_pas 
type:function
takes:scalar variable with a value of a id user and password form,helper db,helper sql
return:An undef is returned if an error occurs or true if the string changed
=cut
sub update_pas {
	my ($id_user,$password,$db,$sql)=@_;
	my $table='users';
	my %fieldvals=(password=>"$password");
	my %where=(id_user=>"$id_user");
	my($stmt,@bind)=$sql->update($table,\%fieldvals,\%where);
	my $sth =$db->prepare($stmt);
        $sth->execute(@bind);
}
=pod
aut
type:controller method
takes:method name
return:html template
=cut
sub aut {
	my $self=shift;
	if (my $cookie=$self->every_signed_cookie('login')->[0]){
	   $self->render(template => 'users/meny');
        }else{
    	   $self->render(template => 'users/aut');
        }
}
=pod
meny
type:controller method
takes:method name, data with form
return:html template or message of incorrect data
=cut
sub meny {
	my $self=shift;
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $get_check=$self->check_forms($login,$password);
	if (!defined $get_check) {
	   $self->render(text=>"Введены некорректные данные с формы,перейдите на страницу входа",status=>403);	
    }
    #my $cookie=$self->signed_cookie("$login");
    my $sql=$self->sql;
    my %insertion_data_user=get_hash_user($login,$password);
    my $id_user=user_exists(\%insertion_data_user,$self->db,$sql);
    if($id_user){
    	$self->signed_cookie(login =>$login,{expires => time + 2000});
    }else{
    	$self->render(text =>'Неверное имя пользователя / пароль',status => 403);
    }
}
=pod
registration
type:controller method
takes:method name, data with form
return:html template or message of incorrect data
=cut
sub registration {
	my $self=shift;
	my $login=$self->param('login');
	my $password=$self->param('password');
	my $confirm_pas=$self->param('confirm-pas');
	my $mail=$self->param('email');
	my $get_check=$self->check_forms($login,$password,$confirm_pas,$mail);
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
        insertions('users',\%insertion_data_user,$self->db,$sql);
        my $id_user=get_id_user($login,$self->db,$sql);
        my %insertion_data_mail=get_hash_mail($id_user,$mail);
        insertions('email',\%insertion_data_mail,$self->db,$sql);
}
=pod
sendmail
type:controller method
takes:method name, data with form
return:html template or message of incorrect data
=cut
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
1;
