@echo off
REM Zoidbot Deployment Integration Tests Runner
REM Batch file to easily run deployment tests from Windows
REM
REM Version: 1.0.0
REM Author: Zoidbot Development Team
REM Last Updated: 2025-07-18

echo === Zoidbot Deployment Integration Tests ===
echo.

REM Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: PowerShell is not available in PATH
    exit /b 1
)

REM Parse command line arguments
set TEST_SUITE=All
set ENVIRONMENT=Staging
set GENERATE_REPORT=
set VERBOSE=

:parse_args
if "%~1"=="" goto run_tests
if /i "%~1"=="-TestSuite" (
    set TEST_SUITE=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-Environment" (
    set ENVIRONMENT=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-GenerateReport" (
    set GENERATE_REPORT=-GenerateReport
    shift
    goto parse_args
)
if /i "%~1"=="-Verbose" (
    set VERBOSE=-Verbose
    shift
    goto parse_args
)
if /i "%~1"=="-Help" (
    goto show_help
)
shift
goto parse_args

:show_help
echo Zoidbot Deployment Integration Tests Runner
echo.
echo USAGE:
echo   run-deployment-tests.bat [options]
echo.
echo OPTIONS:
echo   -TestSuite ^<All^|Basic^|ErrorScenarios^|KiroHook^|Performance^>  Test suite to run (default: All)
echo   -Environment ^<Local^|Staging^>                               Target test environment (default: Staging)
echo   -GenerateReport                                           Generate HTML report
echo   -Verbose                                                  Enable verbose logging
echo   -Help                                                     Show this help message
echo.
echo EXAMPLES:
echo   run-deployment-tests.bat                      # Run all tests
echo   run-deployment-tests.bat -TestSuite Basic     # Run basic tests only
echo   run-deployment-tests.bat -GenerateReport      # Run all tests and generate HTML report
echo.
exit /b 0

:run_tests
echo Running deployment integration tests...
echo Test Suite: %TEST_SUITE%
echo Environment: %ENVIRONMENT%
echo.

REM Set execution policy and run the PowerShell script
powershell -ExecutionPolicy Bypass -File "%~dp0powershell\Run-DeploymentIntegrationTests.ps1" -TestSuite %TEST_SUITE% -Environment %ENVIRONMENT% %GENERATE_REPORT% %VERBOSE%

if %ERRORLEVEL% equ 0 (
    echo.
    echo Tests completed successfully!
) else (
    echo.
    echo Some tests failed. See logs for details.
)

exit /b %ERRORLEVEL%