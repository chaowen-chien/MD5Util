# --------------------------------------------------------------------
# MD5 檔案分割
# --------------------------------------------------------------------
use strict;
use warnings;
use utf8;

use mylib;
use b2u;
use file;

# ---- 讀取命令列參數 ------------------------------------------------

my $infile;                             # 輸入檔案
my $infile_l;                           # 輸入檔案的長檔名路徑
my $infile_s;                           # 輸入檔案的短檔名路徑
my $infile_default = "checksum.md5";    # 預設輸入檔案
my %param;                              # 命令列參數

show_usage() if @ARGV == 1 and $ARGV[0] eq "-h";

for my $var (@ARGV)
{
    if (not $param{$var})
    {
        $infile = $var;
        $param{$var}++;
        next;
    }
    show_usage();
}

$infile //= $infile_default;
$infile_s = Win32::GetShortPathName($infile);
if (not defined $infile_s or not -f $infile_s)
{
    print "File not found.\n";
    exit;
}

# ---- 開啟檔案 ------------------------------------------------------

$infile_l = Win32::GetLongPathName($infile_s);
$infile_l = b2u($infile_l) if not utf8::is_utf8($infile_l);

my $logfile = "$ENV{TEMP}\\md5split.log";
open LOGFILE, ">:raw:encoding(utf16le):crlf", $logfile or die;
print LOGFILE "\x{FEFF}";

# ---- 分割 MD5 檔案 -------------------------------------------------

my $error = 0;      # 錯誤訊息數量
my $warning = 0;    # 警告訊息數量

# 其他檔案列表
my @etcfile = grep {not /\.md5$/i} read_dir("/a:-d");
if (not @etcfile) {warn_log("警告：沒有發現 MD5 檔案以外的其他檔案。")}

# 讀取 MD5 檔案內容
my %md5data;
read_md5();
if ($error) {view_log(); exit}

# 檢查 MD5 檔案內容
my @md5_sorted = sort {lc($a) cmp lc($b)} keys %md5data;    # 按照檔名排序
check_md5();
if ($error) {view_log(); exit}

# 輸出檔案
write_md5();
if ($warning) {view_log(); exit}
close LOGFILE;
unlink $logfile if -s $logfile <= 2;

# --------------------------------------------------------------------
# 顯示使用說明
# --------------------------------------------------------------------
sub show_usage
{
    print << "END";
md5split.pl [filename]
  filename          if omitted, it defaults to $infile_default
END
    exit;
}

# --------------------------------------------------------------------
# 將錯誤訊息寫入記錄檔
# --------------------------------------------------------------------
sub error_log
{
    my $msg = shift;
    print LOGFILE "$msg\n";
    $error++;
}

# --------------------------------------------------------------------
# 將警告訊息寫入記錄檔
# --------------------------------------------------------------------
sub warn_log
{
    my $msg = shift;
    print LOGFILE "$msg\n";
    $warning++;
}

# --------------------------------------------------------------------
# 顯示記錄檔
# --------------------------------------------------------------------
sub view_log
{
    system("start notepad.exe $logfile");
}

# --------------------------------------------------------------------
# 讀取 MD5 檔案
# --------------------------------------------------------------------
sub read_md5
{
    # 開啟 MD5 檔案
    open INFILE, "<:raw", $infile_s or die;

    # 檢查 MD5 檔案格式
    my $hdr = <INFILE>;
    if ($hdr =~ /^\xEF\xBB\xBF/)    # UTF-8 BOM
    {
        binmode(INFILE, ":encoding(utf8)");
        seek(INFILE, 3, 0);
    }
    else
    {
        close INFILE;
        error_log("錯誤：$infile_l 不是 UTF-8 BOM 格式的 MD5 檔案。");
        return;
    }

    # 讀取 MD5 檔案內容
    while (my $str = <INFILE>)
    {
        chomp $str;
        $str =~ s/\s*$//;
        next if $str =~ /^$/;
        if ($str =~ /^([[:xdigit:]]{32}) (?: |\*)(.+$)/)
        {
            my $value = lc($1);
            my $file = $2;
            if (defined $md5data{$file} and $md5data{$file} ne $value)
            {
                error_log("錯誤：$file 有相異的 MD5 值。");
            }
            else
            {
                $md5data{$file} = $value;
            }
        }
        else
        {
            error_log("錯誤：$infile_s 不是 MD5 檔案。");
            last;
        }
    }
    close INFILE;
}

# --------------------------------------------------------------------
# 檢查檔案與 MD5 值
# --------------------------------------------------------------------
sub check_md5
{
    # 檢查檔案是否有 MD5 值
    for my $file (@etcfile)
    {
        if (not $md5data{$file})
        {
            warn_log("警告：$file 沒有 MD5 值。");
        }
    }

    for my $file (@md5_sorted)
    {
        # 檢查 MD5 值對應的檔案是否存在
        if (not exist_file($file))
        {
            warn_log("警告：$file 不存在。");
        }

        # 檢查 MD5 檔案是否已經存在
        if (exist_file("$file.md5"))
        {
            error_log("錯誤：$file.md5 已存在。");
        }
    }
}

# --------------------------------------------------------------------
# 將資料寫入分割後的 MD5 檔案
# --------------------------------------------------------------------
sub write_md5
{
    my $tmpfile = "md5split.tmp";
    for my $file (@md5_sorted)
    {
        open TMPFILE, ">:encoding(utf8)", $tmpfile or die;
        print TMPFILE "\x{FEFF}";
        print TMPFILE "$md5data{$file} \*$file\n";
        close TMPFILE;
        move_file($tmpfile, "$file.md5");
    }
    unlink $infile_s;
}
