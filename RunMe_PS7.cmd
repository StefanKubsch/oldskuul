@ECHO OFF

SET ScriptDir=%~dp0
SET PSScriptPath=%ScriptDir%oldskuul.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process pwsh -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%PSScriptPath%""' -Verb RunAs}";