@echo off
echo 🚀 Starting Flint Application...
if exist .env (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "%%A=%%B"
    )
)
sample.exe
