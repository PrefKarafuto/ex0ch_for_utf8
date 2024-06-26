#============================================================================================================
#
#	バナー管理モジュール
#
#============================================================================================================
package	BANNER;

use strict;
use utf8;
use open ':std', ':encoding(UTF-8)';
use open IO => ':encoding(UTF-8)';
use warnings;

#------------------------------------------------------------------------------------------------------------
#
#	モジュールコンストラクタ - new
#	-------------------------------------------
#	引　数：なし
#	戻り値：モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	
	my $obj = {
		'TEXTPC'	=> undef,	# PC用テキスト
		'TEXTSB'	=> undef,	# サブバナーテキスト
		'TEXTMB'	=> undef,	# 携帯用テキスト
		'COLPC'		=> undef,	# PC用背景色
		'COLMB'		=> undef,	# 携帯用背景色
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	バナー情報読み込み - Load
#	-------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：成功:0,失敗:-1
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'TEXTPC'} = '<tr><td>なるほど告知欄じゃねーの</td></tr>';
	$this->{'TEXTSB'} = '';
	$this->{'TEXTMB'} = '<tr><td>なるほど告知欄じゃねーの</td></tr>';
	$this->{'COLPC'} = '#ccffcc';
	$this->{'COLMB'} = '#ccffcc';
	
	my $path = '.' . $Sys->Get('INFO');
	
	# PC用読み込み
	if (open(my $fh, '<', "$path/bannerpc.cgi")) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		$_ = shift @lines;
		$_ =~ s/[\r\n]+\z//;
		$this->{'COLPC'} = $_;
		$this->{'TEXTPC'} = join '', @lines;
	}
	
	# サブバナー読み込み
	if (open(my $fh, '<', "$path/bannersub.cgi")) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		$this->{'TEXTSB'} = join '', @lines;
	}
	
	# 携帯用読み込み
	if (open(my $fh, '<', "$path/bannermb.cgi")) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		$_ = shift @lines;
		$_ =~ s/[\r\n]+\z//;
		$this->{'COLMB'} = $_;
		$this->{'TEXTMB'} = join '', @lines;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	バナー情報書き込み - Save
#	-------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my @file = ();
	$file[0] = '.' . $Sys->Get('INFO') . '/bannerpc.cgi';
	$file[1] = '.' . $Sys->Get('INFO') . '/bannermb.cgi';
	$file[2] = '.' . $Sys->Get('INFO') . '/bannersub.cgi';
	
	# PC用書き込み
	chmod($Sys->Get('PM-ADM'), $file[0]);
	if (open(my $fh, (-f $file[0] ? '+<' : '>'), $file[0])) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		print $fh $this->{'COLPC'} . "\n";
		print $fh $this->{'TEXTPC'};
		truncate($fh, tell($fh));
		close($fh);
	}
	chmod($Sys->Get('PM-ADM'), $file[0]);
	
	# サブバナー書き込み
	chmod($Sys->Get('PM-ADM'), $file[2]);
	if (open(my $fh, (-f $file[2] ? '+<' : '>'), $file[2])) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		print $fh $this->{'TEXTSB'};
		truncate($fh, tell($fh));
		close($fh);
	}
	chmod($Sys->Get('PM-ADM'), $file[2]);
	
	# 携帯用書き込み
	chmod($Sys->Get('PM-ADM'), $file[1]);
	if (open(my $fh, (-f $file[1] ? '+<' : '>'), $file[1])) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		print $fh $this->{'COLMB'} . "\n";
		print $fh $this->{'TEXTMB'};
		truncate($fh, tell($fh));
		close($fh);
	}
	chmod($Sys->Get('PM-ADM'), $file[1]);
}

#------------------------------------------------------------------------------------------------------------
#
#	バナー情報設定 - Set
#	-------------------------------------------
#	引　数：$key : 設定キー
#			$val : 設定値
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($key, $val) = @_;
	
	$this->{$key} = $val;
}

#------------------------------------------------------------------------------------------------------------
#
#	バナー情報取得 - Get
#	-------------------------------------------
#	引　数：$key : 取得キー
#			$default : デフォルト
#	戻り値：取得値
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($key, $default) = @_;
	
	my $val = $this->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	バナー出力 - Print
#	-------------------------------------------
#	引　数：$Page  : モジュール
#			$width : バナー幅(%)
#			$f     : 区切り表示フラグ
#			$mode  : モード(PC/携帯)
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Print
{
	my $this = shift;
	my ($Page, $width, $f, $mode) = @_;
	
	# 上区切り
	$Page->Print('<hr>') if ($f & 1);
	
	# 携帯用バナー表示
	if ($mode) {
		$Page->Print('<table border width="100%" ');
		$Page->Print("bgcolor=$this->{'COLMB'}>");
		$Page->Print("$this->{'TEXTMB'}</table>\n");
	}
	# PC用バナー表示
	else {
		$Page->Print("<table border=\"1\" cellspacing=\"7\" cellpadding=\"3\" width=\"$width%\"");
		$Page->Print(" bgcolor=\"$this->{'COLPC'}\" align=\"center\">\n");
		$Page->Print("$this->{'TEXTPC'}\n</table>\n");
	}
	
	# 下区切り
	$Page->Print("<hr>\n\n") if ($f & 2);
}

#------------------------------------------------------------------------------------------------------------
#
#	サブバナー出力 - PrintSub
#	-------------------------------------------
#	引　数：$Page : モジュール
#	戻り値：バナー出力したら1,その他は0
#
#------------------------------------------------------------------------------------------------------------
sub PrintSub
{
	my $this = shift;
	my ($Page) = @_;
	
	# サブバナーが存在したら表示する
	if ($this->{'TEXTSB'} ne '') {
		$Page->Print("<div style=\"margin-bottom:1.2em;\">\n");
		$Page->Print("$this->{'TEXTSB'}\n");
		$Page->Print("</div>\n");
		return 1;
	}
	return 0;
}

#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
