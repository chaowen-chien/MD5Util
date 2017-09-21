# --------------------------------------------------------------------
# MD5 檔案合併
# --------------------------------------------------------------------
use strict;
use warnings;
use utf8;

use mylib;
use b2u;
use file;

# ---- 讀取命令列參數 ------------------------------------------------

my $show_log = 0;                        # 是否顯示訊息記錄檔
my $outfile;                             # 輸出檔案
my $outfile_default = "checksum.md5";    # 預設輸出檔案
my %param;                               # 命令列參數

show_usage() if @ARGV == 1 and $ARGV[0] eq "-h";

for my $var (@ARGV)
{
    if ($var eq "-v" and not $param{$var})
    {
        $show_log = 1;
        $param{$var}++;
        next;
    }
    if (not $param{$var})
    {
        $outfile = $var;
        $param{$var}++;
        next;
    }
    show_usage();
}

# ---- 開啟檔案 ------------------------------------------------------

$outfile //= $outfile_default;
$outfile = b2u($outfile) if not utf8::is_utf8($outfile);

my $logfile = "$ENV{TEMP}\\md5join.log";
open LOGFILE, ">:raw:encoding(utf16le):crlf", $logfile or die;
print LOGFILE "\x{FEFF}";

# ---- 合併 MD5 檔案 -------------------------------------------------

my $error = 0;      # 錯誤訊息數量
my $warning = 0;    # 警告訊息數量

# 所有檔案列表
my @allfile = read_dir("/a:-d");
if (not @allfile)
{
    close LOGFILE;
    unlink $logfile;
    exit;
}

# MD5 檔案列表
my @md5file = grep {/\.md5$/i} @allfile;
if (not @md5file)
{
    error_log("錯誤：沒有發現 MD5 檔案。");
    view_log() if $show_log;
    exit;
}

# 其他檔案列表
my @etcfile = grep {not /\.md5$/i} @allfile;
if (not @etcfile) {warn_log("警告：沒有發現 MD5 以外的檔案。")}

# 讀取 MD5 檔案內容
my %md5data;
read_md5();
if ($error and $show_log) {view_log(); exit}

# 檢查 MD5 檔案內容
my @md5data_sorted = sort {lc($a) cmp lc($b)} keys %md5data;    # 按照檔名排序
check_md5();

# 輸出檔案
write_md5();
if ($warning and $show_log) {view_log(); exit}
close LOGFILE;
unlink $logfile if -s $logfile <= 2;

# --------------------------------------------------------------------
# 顯示使用說明
# --------------------------------------------------------------------
sub show_usage
{
    print << "END";
md5join.pl [-v] [filename]
  -v                view log
  filename          if omitted, it defaults to $outfile_default
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
    for my $md5file_l (@md5file)
    {
        # 開啟 MD5 檔案
        my $md5file_s = Win32::GetShortPathName($md5file_l);
        if (not defined $md5file_s)
        {
            error_log("錯誤：$md5file_l 已不存在。");
            view_log() if $show_log;
            exit;
        }
        open INFILE, "<:raw", $md5file_s or die;

        # 檢查 MD5 檔案格式
        my $ansi = 0;
        my $hdr = <INFILE>;
        if ($hdr =~ /^\xEF\xBB\xBF/)    # UTF-8 BOM
        {
            binmode(INFILE, ":encoding(utf8)");
            seek(INFILE, 3, 0);
        }
        elsif ($hdr =~ /^\xFF\xFE/)    # UTF-16LE BOM
        {
            binmode(INFILE, ":encoding(utf16le):crlf");
            seek(INFILE, 2, 0);
        }
        else    # ANSI
        {
            seek(INFILE, 0, 0);
            $ansi = 1;
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
                my $file = $ansi ? b2u($2) : $2;
                if ($md5data{$file} and $md5data{$file} ne $value)
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
                error_log("錯誤：$md5file_l 不是 MD5 檔案。");
                last;
            }
        }
        close INFILE;
    }
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

    # 檢查 MD5 值對應的檔案是否存在
    for my $file (@md5data_sorted)
    {
        if (not exist_file($file))
        {
            warn_log("警告：$file 不存在。");
        }
    }
}

# --------------------------------------------------------------------
# 將資料寫入合併後的 MD5 檔案
# --------------------------------------------------------------------
sub write_md5
{
    my $tmpfile = "$ENV{TEMP}\\md5join.tmp";
    open TMPFILE, ">:encoding(utf8)", $tmpfile or die;
    print TMPFILE "\x{FEFF}";
    for my $file (@md5data_sorted)
    {
        print TMPFILE "$md5data{$file} \*$file\n";
    }
    close TMPFILE;
    system("del /f *.md5 2> nul");
    move_file($tmpfile, $outfile);
}
