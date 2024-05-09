#============================================================================================================
#
#	拡張機能 - ランダム名無し機能
#	0ch_774.pl
#	by uuuss ◆uuussBh4TI ( uuussatm@gmail.com / http://afox.s206.xrea.com/ )
#	---------------------------------------------------------------------------
#	ライセンスについて
#	ライセンスは、ぜろちゃんねる(test060227)と同じです。
#	以下は、ぜろちゃんねる(test060227)配布アーカイブ/readme/readme.txtからの引用です。
#	
#	　本スクリプトは自由に改造・再配布してもらってかまいません。また、本スクリ
#	プトによって出力されるクレジット表示(バージョン表示)などの表示も消して使用
#	してもらっても構いません。
#	　ただし、作者は本スクリプトと付属ファイルに関する著作権を放棄しません。
#	　また、作者は本スクリプト使用に関して発生したいかなるトラブルにも責任を負
#	いかねますのでご了承ください。
#
#	引用ここまで。
#	---------------------------------------------------------------------------
#	2006.10.26 start
#	2006.10.28 キャップ対応を忘れてたので対応させた
#	2006.10.31 キャップ対応のやり方がまずかったのか使いものにならなかったのを直した
#	2006.11.21 毎回ランダム表示の他にIPアドレス＆日替わり表示(2ch互換)にも対応させた＆外部ファイルから名無しリストを読めるようにした
#
#============================================================================================================
#
#	拡張機能 - ランダム名無し機能 Ver1.0
#	0ch_774.pl
#	by 樺太庁長官 ◆i5oJWq7F9Gmc ( karafuto@goatmail.uk / http://pref-karafuto.tk/ )
#	---------------------------------------------------------------------------
#	ライセンスについて
#	ライセンスは、ぜろちゃんねるプラスと同じです。
#
#	2022.12.15 ぜろちゃんねるプラスのコンフィグ機能に対応＆掲示板毎に名無しリストの設定が可能に＆CFに対応
#
#============================================================================================================
package ZPL_774;
use Encode 'from_to';
use utf8;

#------------------------------------------------------------------------------------------------------------
#
#	コンストラクタ
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	オブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	my ($Config) = @_;
	my ($obj);
	
	$obj = {};
	bless $obj, $this;
	
	if (defined $Config) {
		$obj->{'PLUGINCONF'} = $Config;
		$obj->{'is0ch+'} = 1;
	}
	else {
		$obj->{'CONFIG'} = $this->getConfig();
		$obj->{'is0ch+'} = 0;
	}
	
	return $obj;
}
#------------------------------------------------------------------------------------------------------------
#
#	拡張機能名称取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	名称文字列
#
#------------------------------------------------------------------------------------------------------------
sub getName
{
	my	$this = shift;
	return 'ランダム名無し機能\ ';
}

#------------------------------------------------------------------------------------------------------------
#
#	拡張機能説明取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	説明文字列
#
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	my	$this = shift;
	return '名無しをランダムに出来ます。';
}

#------------------------------------------------------------------------------------------------------------
#
#	拡張機能タイプ取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	拡張機能タイプ(スレ立て:1,レス:2,read:4,index:8)
#
#------------------------------------------------------------------------------------------------------------
sub getType
{
	my	$this = shift;
	return (1 | 2 | 16);
}

#------------------------------------------------------------------------------------------------------------
#	設定リスト取得 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	設定ハッシュリファレンス
#		\%config = (
#			'設定名'	=> {
#				'default'		=> 初期値,			# 真偽値の場合は on/true: 1, off/false: 0
#				'valuetype'		=> 値のタイプ,		# 数値: 1, 文字列: 2, 真偽値: 3
#				'description'	=> '設定の説明',	# 無くても構いません
#			},
#		);
#------------------------------------------------------------------------------------------------------------
sub getConfig
{
	my	$this = shift;
	my	%config;
	
	%config = (
		'強制名無し'	=> {
		    'default'		=> 0,
			'valuetype'		=> 3,
			'description'	=> '強制的に名無しにします。',
		},
		'名無し太字'	=> {
		    'default'		=> 1,
			'valuetype'		=> 3,
			'description'	=> '名無しを太字で表示します。',
		},
		'IPに紐付け'	=> {
		    'default'		=> 1,
			'valuetype'		=> 3,
			'description'	=> '名無しを日替わりでIPに紐付けます。無効にすると毎回ランダムになります。',
		},
		'掲示板ごとに名無しリストを使う'	=> {
		    'default'		=> 1,
			'valuetype'		=> 3,
			'description'	=> '掲示板ごとに用意された名無しリストを使用します。リストはデフォルトでbbs.cgiから見て../[掲示板ディレクトリ名]/info/774list.cgiです。リストに何も載っていない場合はデフォルトの名前になります。無効にした場合、内部のリストが使用されます。',
		}
	);
	
	return \%config;
}

#------------------------------------------------------------------------------------------------------------
#
#	拡張機能実行インタフェイス
#	-------------------------------------------------------------------------------------
#	@param	$sys	MELKOR
#	@param	$form	SAMWISE
#	@return	正常終了の場合は0
#
#------------------------------------------------------------------------------------------------------------
sub execute
{
	my $this = shift;
	my ($sys,$form,$type) = @_;
	my $bbs = $sys->Get('BBS');

	my $force_nanashi = $this->GetConf('強制名無し');
	my $bold_nanashi = $this->GetConf('名無し太字');
	my $change_nanashi = $this->GetConf('IPに紐付け');
  my $location_nanashi = sprintf("../%s/info/774list.cgi",$bbs);  #名無しリストはUTF8で保存すること

    open (NANASHILISTFILE,">>", $location_nanashi);
    chmod (0600,$location_nanashi);
    close NANASHILISTFILE;

	if ($type eq 16 and $sys->Get('ZPL_774_true') and $form->Get('FROM') !~ /(★)/) {
		my $i = 0;
		my $randout_nanashi;
		if ($this->GetConf('掲示板ごとに名無しリストを使う') eq 0) {
			my @nanashi = ('名無しさん＠お腹いっぱい' , 'ひよこ名無しさん' , '番組の途中ですが名無しです');
		}
		else {
			open (NANASHILISTFILE, $location_nanashi);
			while (<NANASHILISTFILE>) {
				$_ =~ s/([\r\n])//g;
				if ($_ ne '') {
					$nanashi[$i] = $_;
					$i ++;
				}
			}
			close NANASHILISTFILE;
		}
        if ($i == 0){return 0;}
		if ($change_nanashi) {
			my (undef, undef, undef, $day, $mon, undef, $wday) = localtime;
			my (undef, undef, undef, $ipaddr) = split(/\./, (defined($ENV{'HTTP_CF_CONNECTING_IP'})?$ENV{'HTTP_CF_CONNECTING_IP'}:$ENV{'REMOTE_ADDR'}));
			$i = $ipaddr + $mon + $day + $wday;
			while ($i > @nanashi){
				$i -= @nanashi;
			}
			$randout_nanashi = $nanashi[$i];
		}
		else {
			$randout_nanashi = $nanashi[int(rand(scalar @nanashi))];
		}
        from_to($randout_nanashi,'UTF-8','UTF-8');
		if ($bold_nanashi) {
			$form->Set('FROM',$randout_nanashi);
		}
		else {
			$form->Set('FROM','</b>' . $randout_nanashi . '<b>');
		}
	}
	elsif ($force_nanashi or $form->Get('FROM') eq '') {
		$sys->Set('ZPL_774_true',1);
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#	設定値取得 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	$key	設定名
#	@return	設定値
#------------------------------------------------------------------------------------------------------------
sub GetConf
{
	my	$this = shift;
	my	($key) = @_;
	my	($val);
	
	if ($this->{'is0ch+'}) {
		$val = $this->{'PLUGINCONF'}->GetConfig($key);
	}
	else {
		if (defined $this->{'CONFIG'}->{$key}) {
			$val = $this->{'CONFIG'}->{$key}->{'default'};
		}
		else {
			$val = undef;
		}
	}
	
	return $val;
}

#------------------------------------------------------------------------------------------------------------
#	設定値設定 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	$key	設定名
#	@param	$val	設定値
#	@return	なし
#------------------------------------------------------------------------------------------------------------
sub SetConf
{
	my	$this = shift;
	my	($key, $val) = @_;
	
	if ($this->{'is0ch+'}) {
		$this->{'PLUGINCONF'}->SetConfig($key, $val);
	}
	else {
		if (defined $this->{'CONFIG'}->{$key}) {
			$this->{'CONFIG'}->{$key}->{'default'} = $val;
		}
		else {
			$this->{'CONFIG'}->{$key} = { 'default' => $val };
		}
	}
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
