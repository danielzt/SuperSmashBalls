@echo off
rem Abre o Super Smash Balls no editor do Godot.
cd /d "%~dp0"
"C:\Users\danza\Godot\Godot_v4.7.2-stable_win64.exe" --editor --path .
if errorlevel 1 pause
