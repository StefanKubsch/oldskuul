$path = Resolve-Path ClassChunky.cs  
$compiler = "$env:windir/Microsoft.NET/Framework/v2.0.50727/csc"  
&$compiler /target:library ClassChunky.cs /unsafe 
dir ClassChunky*
