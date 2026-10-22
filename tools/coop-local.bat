@echo off
rem Teste de coop local (Etapa D+): abre duas janelas do jogo NESTE PC.
rem A primeira hospeda so para este computador (127.0.0.1, nenhuma porta aberta para a rede);
rem a segunda entra nela como segundo jogador.
set "GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot nao encontrada em %GODOT%
  pause
  exit /b 1
)
cd /d "%~dp0.."
start "Host" "%GODOT%" --path . --position 20,40 -- --host
rem Espera ~2 s o host abrir (ping funciona em qualquer Windows).
ping -n 3 127.0.0.1 > nul
start "Cliente" "%GODOT%" --path . --position 620,320 -- --join=127.0.0.1
