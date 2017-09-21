# --------------------------------------------------------------------
# 檔案相關函式
# --------------------------------------------------------------------
package file;
use strict;
use warnings;
use utf8;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT =
qw(
    exist_dir exist_file exist_path
    copy_file move_file
    current_path read_path read_dir
);
our %EXPORT_TAGS =
(
    exist => [qw(exist_dir exist_file exist_path)],
    file  => [qw(copy_file move_file)],
    list  => [qw(current_path read_path read_dir)],
);

use Encode;
use Win32API::File qw(:FuncW :FILE_ATTRIBUTE_ :MOVEFILE_);

# --------------------------------------------------------------------
# 檢查 Unicode 路徑
# --------------------------------------------------------------------
sub exist_path
{
    my $path = encode("utf16le", "$_[0]\0");
    my $attr = GetFileAttributesW($path);
    return 0 if $attr == INVALID_FILE_ATTRIBUTES;
    return 1;
}

# --------------------------------------------------------------------
# 檢查 Unicode 目錄
# --------------------------------------------------------------------
sub exist_dir
{
    my $file = encode("utf16le", "$_[0]\0");
    my $attr = GetFileAttributesW($file);
    return 0 if not $attr & FILE_ATTRIBUTE_DIRECTORY;
    return 1;
}

# --------------------------------------------------------------------
# 檢查 Unicode 檔案
# --------------------------------------------------------------------
sub exist_file
{
    my $file = encode("utf16le", "$_[0]\0");
    my $attr = GetFileAttributesW($file);
    return 0 if $attr == INVALID_FILE_ATTRIBUTES
        or $attr & FILE_ATTRIBUTE_DIRECTORY;
    return 1;
}

# --------------------------------------------------------------------
# 複製 Unicode 檔案
# --------------------------------------------------------------------
sub copy_file
{
    my $old = shift;
    my $new = shift;
    my $overwrite = shift // 0;
    $old = encode("utf16le", "$old\0");
    $new = encode("utf16le", "$new\0");
    return CopyFileW($old, $new, ($overwrite == 1 ? 0 : 1));
}

# --------------------------------------------------------------------
# 移動或更改 Unicode 檔案及目錄 (無法將目錄移到不同的磁碟機)
# --------------------------------------------------------------------
sub move_file
{
    my $old = shift;
    my $new = shift;
    my $overwrite = shift // 0;
    $old = encode("utf16le", "$old\0");
    $new = encode("utf16le", "$new\0");
    return MoveFileExW($old, $new, ($overwrite == 1 ?
        MOVEFILE_COPY_ALLOWED | MOVEFILE_REPLACE_EXISTING :
        MOVEFILE_COPY_ALLOWED));
}

# --------------------------------------------------------------------
# 讀取目前路徑
# --------------------------------------------------------------------
sub current_path
{
    my $dir = "$ENV{ComSpec} /u /c cd";
    my $path;
    open DIR, "-|:encoding(utf16le):crlf", $dir or die;
    chomp($path = <DIR>);
    close DIR;
    return $path;
}

# --------------------------------------------------------------------
# 讀取所有路徑
# --------------------------------------------------------------------
sub read_path
{
    my $dir = "$ENV{ComSpec} /u /c cd & dir /b /s /a:d /o:gn";
    open DIR, "-|:encoding(utf16le):crlf", $dir or die;
    my @dir;
    while (my $path = <DIR>)
    {
        chomp $path;
        push @dir, $path;
    }
    close DIR;
    return @dir;
}

# --------------------------------------------------------------------
# 讀取檔案列表
# --------------------------------------------------------------------
sub read_dir
{
    my $path = shift // "";
    # 避免顯示「找不到檔案」訊息，加上「2> nul」
    my $dir = "$ENV{ComSpec} /u /c dir /b /o:gn $path 2> nul";
    open DIR, "-|:encoding(utf16le):crlf", $dir or die;
    my @dir;
    while (my $file = <DIR>)
    {
        chomp $file;
        push @dir, $file;
    }
    close DIR;
    return @dir;
}
