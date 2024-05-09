#============================================================================================================
#
#	httpサービスモジュール
#
#============================================================================================================
package HTTP_SERVICE;

use strict;
use utf8;
use open ':std', ':encoding(UTF-8)';
use open IO => ':encoding(UTF-8)';
use warnings;

use Socket;

#------------------------------------------------------------------------------------------------------------
#
#	コンストラクタ
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	httpサービスオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	
	my $obj = {
		'METHOD'		=> 'GET',
		'URI'			=> undef,
		'PARAMETER'		=> undef,
		'CONTENT_TYPE'	=> 'application/x-www-form-urlencoded',
		'REFERER'		=> undef,
		'AGENT'			=> 'Mozilla/5.0 Zero-Channel BBS Plus Project',
		'CONNECTION'	=> 'close',
		'LANGUAGE'		=> 'ja,en-us;q=0.7,en;q=0.3',
		'PROXY_HOST'	=> undef,
		'PROXY_PORT'	=> undef,
		'TIMEOUT'		=> 3,
		
		'CODE'			=> 500,
		'HEADER'		=> undef,
		'CONTENT'		=> undef
	};
	bless $obj, $class;
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	http要求送信
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	エラーコード
#			1:正常終了
#			-1:URIエラー
#			-2:socketエラー
#
#------------------------------------------------------------------------------------------------------------
sub request
{
	my $this = shift;
	
	# URIを分解
	my $uri = $this->{'URI'};
	my ($host, $port, $target) = decompositionURI($uri);
	
	return -1 if (!defined $host);
	
	# プロキシを使用する
	if (defined $this->{'PROXY_HOST'}) {
		$host = $this->{'PROXY_HOST'};
		$port = $this->{'PROXY_PORT'} || 80;
		$target = $uri;
	}
	
	# リクエストクエリの作成
	my $request = createRequestString($this, $host, $target);
	
	eval
	{
		local $SIG{'ALRM'} = sub { die "connect time out. $!" };
		
		alarm($this->{'TIMEOUT'});
		
		# ソケットの作成
		my $sockaddr = pack_sockaddr_in($port, inet_aton($host));
		socket(SOCKET, PF_INET, SOCK_STREAM, 0);
		select(SOCKET);
		$| = 1;
		select(STDOUT);
		connect(SOCKET, $sockaddr);
		#binmode(SOCKET);
		#autoflush SOCKET (1);
		
		# リクエスト送信
		print SOCKET $request;
		$this->{'REQUEST'} = $request;
		
		my $chunkedflag = 0;
		my $code = -1;
		my $header = '';
		my $content = '';
		
		while (<SOCKET>) {
			$_ =~ s/[\r\n]+\z//;
			
			last if ($_ eq '');
			
			# HTTPステータス
			if ($_ =~ m|^HTTP/\d.\d\s+(\d+)|) {
				$code = $1;
			}
			
			# レスポンスヘッダーの取得
			$header .= "$_\n";
		}
		
		# Chunked Transfer Coding
		# http://tools.ietf.org/html/rfc2616#section-14.41
		if ($header =~ m|Transfer\-Encoding:\s*chunked|i) {
			$chunkedflag = 1;
		}
		
		# 本文の取得
		if ($chunkedflag) {
			# http://tools.ietf.org/html/rfc2616#section-3.6.1
			while (<SOCKET>) {
				$_ = /^([0-9A-F]+)/i;
				my $size = hex $1;
				
				last if ($size eq 0);
				
				read(SOCKET, $_, $size);
				$content .= $_;
				
				<SOCKET>;
			}
			
			# http://tools.ietf.org/html/rfc2616#section-7.1
			while ( <SOCKET> ) {
				$_ =~ s/[\r\n]+\z//;
				
				last if ( $_ eq '' );
				
				# レスポンスヘッダーの取得
				$header .= "$_\n";
				
			}
		}
		else {
			while (read(SOCKET, $_, 1024)) {
				$content .= $_;
			}
		}
		
		close(SOCKET);
		
		$this->{'CODE'} = $code;
		$this->{'HEADER'} = $header;
		$this->{'CONTENT'} = $content;
		
		alarm(0);
	};
	
	if ($@) {
		$this->{'CODE'} = -1;
		$this->{'CONTENT'} = $@;
		return -2;
	}
	
	return 1;
}

#------------------------------------------------------------------------------------------------------------
#
#	URI分解
#	-------------------------------------------------------------------------------------
#	@param	$uri	URI
#	@return	$host	ホスト
#			$port	ポート番号
#
#------------------------------------------------------------------------------------------------------------
sub decompositionURI
{
	
	my ($uri) = @_;
	
	$uri =~ m!(?:(?:http:)?//)?((?:[^:/]*)?)(?::(\d*))?(/.*)!;
	my $host = $1;
	my $port = $2 || 80;
	my $path = $3;
	
	return ($host, $port, $path);
}

#------------------------------------------------------------------------------------------------------------
#
#	http要求文字列の生成
#	-------------------------------------------------------------------------------------
#	@param	$host	http要求先アドレス
#			$target	http要求先URI
#	@return	http要求ヘッダ文字列
#
#------------------------------------------------------------------------------------------------------------
sub createRequestString
{
	my $this = shift;
	my ($host, $target) = @_;
	
	# httpボディ(パラメータ)の作成
	my $params = '';
	my $len = 0;
	foreach my $key (keys %{$this->{'PARAMETER'}}) {
		my $value = encode($this->{'PARAMETER'}->{$key});
		$params .= "&$key=$value";
	}
	if ($params ne '') {
		$params = substr($params, 1);
		$len = length $params;
	}
	
	my $request = '';
	$request .= "$this->{'METHOD'} $target HTTP/1.1\r\n";
	$request .= "Host: $host\r\n";
	$request .= "User-Agent: $this->{'AGENT'}\r\n";
	$request .= "Accept-Language: $this->{'LANGUAGE'}\r\n";
	$request .= "Content-Type: $this->{'CONTENT_TYPE'}\r\n";
	$request .= "Keep-Alive: 115\r\n";
	$request .= "Referer: $this->{'REFERER'}\r\n" if ($this->{'REFERER'});
	$request .= "Connection: $this->{'CONNECTION'}\r\n";
	$request .= "Content-Length: $len\r\n" if ($this->{'METHOD'} eq 'POST');
	
	$request .= "\r\n";
	
	$request .= $params if ($this->{'METHOD'} eq 'POST');
	
	return $request;
}

#------------------------------------------------------------------------------------------------------------
#
#	URLエンコード
#	-------------------------------------------------------------------------------------
#	@param	$text	エンコード文字列
#	@return	URLエンコードした文字列
#
#------------------------------------------------------------------------------------------------------------
sub encode
{
	
	my ($str) = @_;
	$str =~ s/([^\w ])/'%'.unpack('H2', $1)/eg;
	$str =~ tr/ /+/;
	return $str;
}

#------------------------------------------------------------------------------------------------------------
#
#	http応答ヘッダー取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	http応答ヘッダー
#
#------------------------------------------------------------------------------------------------------------
sub getHeader
{
	my $this = shift;
	return $this->{'HEADER'};
}

#------------------------------------------------------------------------------------------------------------
#
#	http応答HTTPステータス取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	httpステータス
#
#------------------------------------------------------------------------------------------------------------
sub getStatus
{
	my $this = shift;
	return $this->{'CODE'};
}

#------------------------------------------------------------------------------------------------------------
#
#	http応答コンテンツ取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	http取得先コンテンツ http要求でsocketエラーが起きた場合はエラーメッセージ
#
#------------------------------------------------------------------------------------------------------------
sub getContent
{
	my $this = shift;
	return $this->{'CONTENT'};
}

#------------------------------------------------------------------------------------------------------------
#
#	http要求先uri設定
#	-------------------------------------------------------------------------------------
#	@param	$uri	URI
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setURI
{
	my $this = shift;
	my ($uri) = @_;
	$this->{'URI'} = $uri;
}

#------------------------------------------------------------------------------------------------------------
#
#	http要求先ポート設定
#	-------------------------------------------------------------------------------------
#	@param	$port	ポート番号
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setPort
{
	my $this = shift;
	my ($port) = @_;
	$this->{'PORT'} = $port;
}

#------------------------------------------------------------------------------------------------------------
#
#	http要求メソッド設定
#	-------------------------------------------------------------------------------------
#	@param	$method	メソッド名
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setMethod
{
	my $this = shift;
	my ($method) = @_;
	$this->{'METHOD'} = $method;
}


#------------------------------------------------------------------------------------------------------------
#
#	UserAgent設定
#	-------------------------------------------------------------------------------------
#	@param	$agent	UserAgent
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setAgent
{
	my $this = shift;
	my ($agent) = @_;
	$this->{'AGENT'} = $agent;
}

#------------------------------------------------------------------------------------------------------------
#
#	タイムアウト設定
#	-------------------------------------------------------------------------------------
#	@param	$time	タイムアウト時間(秒)
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setTimeout
{
	my $this = shift;
	my ($time) = @_;
	$this->{'TUMEOUT'} = $time;
}

#------------------------------------------------------------------------------------------------------------
#
#	コンテントタイプ設定
#	-------------------------------------------------------------------------------------
#	@param	$type	コンテントタイプ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setContentType
{
	my $this = shift;
	my ($type) = @_;
	$this->{'CONTENT_TYPE'} = $type;
}

#------------------------------------------------------------------------------------------------------------
#
#	コネクション設定
#	-------------------------------------------------------------------------------------
#	@param	$conn	コネクション
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setConnection
{
	my $this = shift;
	my ($conn) = @_;
	$this->{'CONNECTION'} = $conn;
}

#------------------------------------------------------------------------------------------------------------
#
#	リファラ設定
#	-------------------------------------------------------------------------------------
#	@param	$ref	リファラ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setReferer
{
	my $this = shift;
	my ($ref) = @_;
	$this->{'REFERER'} = $ref;
}

#------------------------------------------------------------------------------------------------------------
#
#	プロキシ設定
#	-------------------------------------------------------------------------------------
#	@param	$proxy	プロキシ ( [host]:[port]形式で )
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setProxy
{
	my $this = shift;
	my ($proxy) = @_;
	my ($host, $port) = split(/:/, $proxy);
	$this->{'PROXY_HOST'} = $host;
	$this->{'PROXY_PORT'} = $port;
}

#------------------------------------------------------------------------------------------------------------
#
#	言語設定
#	-------------------------------------------------------------------------------------
#	@param	$lang	言語
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setLanguage
{
	my $this = shift;
	my ($lang) = @_;
	$this->{'LANGUAGE'} = $lang;
}

#------------------------------------------------------------------------------------------------------------
#
#	http要求パラメータ設定
#	-------------------------------------------------------------------------------------
#	@param	$key	パラメータキー
#	@param	$value	パラメータ値
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub setParameter
{
	my $this = shift;
	my ($key, $value) = @_;
	$this->{'PARAMETER'}->{$key} = $value;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
