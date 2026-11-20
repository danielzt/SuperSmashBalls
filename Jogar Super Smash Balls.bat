@echo off
rem Abre o Super Smash Balls direto no jogo (sem o editor).
cd /d "%~dp0"
"C:\Users\danza\Godot\Godot_v4.7.2-stable_win64.exe" --path .
if errorlevel 1 pause
