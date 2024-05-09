package CGI::Session::Driver;use strict;use Carp;use CGI::Session::ErrorHandler;$CGI::Session::Driver::VERSION='4.43';@CGI::Session::Driver::ISA=qw(CGI::Session::ErrorHandler);sub new{my$class=shift;my$args=shift||{};unless(ref$args){croak"$class->new(): Invalid argument type passed to driver";}if(!$args->{TableName}){$args->{TableName}='sessions';}if(!$args->{IdColName}){$args->{IdColName}='id';}if(!$args->{DataColName}){$args->{DataColName}='a_session';}my$self=bless({%$args},$class);return$self if$self->init();return$self->set_error("$class->init() returned false");}sub init{1}sub retrieve{croak"retrieve(): ".ref($_[0])." failed to implement this method!";}sub store{croak"store(): ".ref($_[0])." failed to implement this method!";}sub remove{croak"remove(): ".ref($_[0])." failed to implement this method!";}sub traverse{croak"traverse(): ".ref($_[0])." failed to implement this method!";}sub dump{require Data::Dumper;my$d=Data::Dumper->new([$_[0]],[ref$_[0]]);return$d->Dump;}1;__END__