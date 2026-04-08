@echo off
:: Launch Tunnex with admin rights (required for TUN mode)
powershell -Command "Start-Process '%~dp0tunnex.exe' -Verb RunAs -WorkingDirectory '%~dp0'"
