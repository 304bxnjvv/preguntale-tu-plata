Get-Content .env | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]*)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
}
uvicorn app.main:app --reload --port 8000
