@echo off
rem Teste do codigo da partida (Etapa I1): abre tres janelas do jogo NESTE PC.
rem 1) Host que exige o codigo ABCD2345 (so para este computador, nenhuma porta aberta para a rede).
rem 2) Cliente com o codigo ERRADO: deve mostrar "Codigo da partida errado" e nao entrar.
rem 3) Cliente com o codigo CERTO: deve entrar no jogo como segundo jogador.
set "GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot nao encontrada em %GODOT%
  pause
  exit /b 1
)
cd /d "%~dp0.."
start "Host" "%GODOT%" --path . --position 20,40 -- --host --code=ABCD2345
rem Espera ~2 s o host abrir (ping funciona em qualquer Windows).
ping -n 3 127.0.0.1 > nul
start "Codigo errado" "%GODOT%" --path . --position 620,40 -- --join=127.0.0.1 --code=ZZZZZZZZ
ping -n 3 127.0.0.1 > nul
start "Codigo certo" "%GODOT%" --path . --position 320,360 -- --join=127.0.0.1 --code=abcd-2345
