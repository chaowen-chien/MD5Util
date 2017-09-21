# MD5Util #

MD5 檔案一般是用來校驗檔案的雜湊值 (Hash Value)，確保檔案在資訊傳輸過程中沒有損壞，詳細說明可以參考 [MD5 - 維基百科](https://zh.wikipedia.org/wiki/MD5) 。以 Visual Studio 2015 Community 繁體中文版的 ISO 檔案為例，其 MD5 檔案內容如下：

```
5bb7876b4a06c4e05b5ff8470808f23c *vs2015.com_cht.iso
```

然而 MD5 檔案本身並沒有特定編碼格式，取得的 MD5 檔案可能是 ANSI 也可能是 UTF-16LE，甚至是 Big5-UAO ( [Unicode 補完計畫 - 維基百科](https://zh.wikipedia.org/wiki/Unicode%E8%A3%9C%E5%AE%8C%E8%A8%88%E7%95%AB) )，導致處理大量 MD5 檔案的合併與分割相當瑣碎麻煩，手動編輯也經常會出現疏漏。於是個人便撰寫了這個 Perl Script，節省整理 MD5 檔案的時間。程式執行結果如圖所示：

![](/Image/Example.gif "MD5 檔案的合併與分割")

程式支援 Unicode 檔名，會依據 BOM 檔頭自動轉換 MD5 檔案編碼 (將 ANSI、CP950、Big5-UAO、UTF-16LE 轉換為 UTF-8)，並檢查 MD5 值對應的檔案是否存在、檔名是否重複，工作路徑下的檔案是否有對應的 MD5 值等等。

md5split 不包含轉換檔案編碼功能，如果不確定 MD5 檔案編碼是否為 UTF-8，請在執行 md5split 之前先執行一次 md5join。
