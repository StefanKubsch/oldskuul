@ECHO OFF

SET ScriptDir=%~dp0
SET PSScriptPath=%ScriptDir%oldskuul.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%PSScriptPath%""' -Verb RunAs}";