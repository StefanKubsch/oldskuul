$path = Resolve-Path ClassChunky.cs  
$compiler = "$env:windir/Microsoft.NET/Framework/v4.0.30319/csc"  
&$compiler /target:library ClassChunky.cs /unsafe 
dir ClassChunky*
