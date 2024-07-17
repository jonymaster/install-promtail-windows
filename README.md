# Install-Promtail-windows Powershell script
Powershell script to install Promtail for Windows hosts to get Windows Events

## Usage
### Installation
1. Download the script
2. Run the script with elevated privileges
3. The script will download the latest Promtail version and install it as a service
### Editing the configuration
1. Stop the service
2. Edit the configuration file located at `C:\Promtail\promtail.yml`
3. You can run the application in debug mode to check if the configuration is correct. 
To do so, run the command: `.\promtail-windows-amd64.exe --config.file=promtail.yml --config.expand-env=true`
from the `C:\Promtail` directory

## Configuration

A default configuration file is installed by the script to get all the Windows Events. 
You can modify the configuration file located at `C:\Promtail\promtail.yml` 
to filter the events you want to collect.

You can use xpath_queries to filter the events of interest. Please refer to the 
[Loki documentation](https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#windows_events) 
for more information.

In order to use an environment variable in the configuration file, you can use the syntax `${ENV_VAR}`.
To avoid having to store a system-wide environment variable, follow the following steps:

1. Create a REG_MULTI_SZ registry value named Environment under 
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service-name-that-you-used-for-the-otel-collector>
2. On this multistring value each line represents an environment variable visible only to the specific service. 
The syntax of each line is the name of the environment variable followed by an =, 
everything after the sign until the end of the line is the value of the environment variable.
    For example, for `LOKI_AUTH` add a line like:
    `LOKI_AUTH=<your-value-for-otel-auth>`