# Create a folder under the drive root
mkdir actions-runner

cd actions-runner # Download the latest runner package

Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.305.0/actions-runner-win-x64-2.305.0.zip -OutFile actions-runner-win-x64-2.305.0.zip

# Optional: Validate the hash
if ((Get-FileHash -Path actions-runner-win-x64-2.305.0.zip -Algorithm SHA256).Hash.ToUpper() -ne '3a4afe6d9056c7c63ecc17f4db32148e946454f2384427b0a4565b7690ef7420'.ToUpper()) { 
    throw 'Computed checksum did not match' 
}

# Extract the installer
Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/actions-runner-win-x64-2.305.0.zip", "$PWD")

./config.cmd --url https://github.com/cbellee/kv-pe-gh-runner --token ACB4EKRK2R4BQO3TUDUSVC3ESPKB4

./run.cmd