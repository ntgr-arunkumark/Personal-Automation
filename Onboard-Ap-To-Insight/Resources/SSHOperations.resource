*** Settings ***
Library           SSHLibrary
Library           Collections
Library           SeleniumLibrary
Library           String
Library           Process

*** Keywords ***

SSH Open Access
    [Documentation]    Attempts SSH or Reverse SSH to device, up to 3 retries.
    ...                Enables SSH/Reverse SSH via UI if both fail. Supports password or keyfile auth.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias for the device
    ...                - host (mandatory): SSH host/IP
    ...                - username (mandatory): SSH username
    ...                - password (optional): Password or key passphrase (default None)
    ...                - port (optional): SSH port (default 22)
    ...                - keyfile (optional): Path to private/public key file (default None)
    ...                - reverse_host (optional): Reverse SSH host/IP (default None)
    ...                - reverse_port (optional): Reverse SSH port (default 22)
    ...
    ...                RETURNS: None. Fails if connection unsuccessful after 3 retries.
    [Arguments]    &{arguments}
    ${device}              Get From Dictionary    ${arguments}    device
    ${host}                Get From Dictionary    ${arguments}    host                default=None  #
    ${username}            Get From Dictionary    ${arguments}    username            default=None  #
    ${password}            Get From Dictionary    ${arguments}    password            default=None  #
    ${keyfile}             Get From Dictionary    ${arguments}    keyfile             default=None
    ${port}                Get From Dictionary    ${arguments}    port                default=22
    ${reverse_host}        Get From Dictionary    ${arguments}    reverse_host        default=None
    ${reverse_username}    Get From Dictionary    ${arguments}    reverse_username    default=None
    ${reverse_keyfile}     Get From Dictionary    ${arguments}    reverse_keyfile             default=None
    ${reverse_port}        Get From Dictionary    ${arguments}    reverse_port        default=443
    ${sdm_port}            Get From Dictionary    ${arguments}    sdm_port            default=None

    Enable Ssh Logging    ${host}
    FOR    ${i}    IN RANGE    3
        Log    SSH Open Access Attempt ${i + 1}
        ${ssh_status}    Run Keyword And Return Status    Evaluate SSH Connection
        ...    ${device}    ${host}    ${port}    ${username}    ${password}    ${keyfile}

        Run Keyword If    ${ssh_status}    Exit For Loop

        ${ssh_status}    Run Keyword And Return Status    Evaluate Reverse SSH Connection
        ...    ${device}    ${reverse_host}    ${reverse_port}    ${sdm_port}    ${reverse_username}    ${reverse_keyfile}
    
        Run Keyword If    ${ssh_status}    Exit For Loop
        Log    Both SSH and Reverse SSH failed on attempt ${i + 1}, enabling via UI and retrying
        # Enable SSH And Reverse SSH In UI
    END
    Run Keyword If    not ${ssh_status}    Fail    SSH Open Access failed after 3 retries

Evaluate SSH Connection
    [Documentation]    Opens SSH connection and logs in using password or public key.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - host (mandatory): SSH host/IP
    ...                - port (mandatory): SSH port
    ...                - username (mandatory): Username
    ...                - password (optional): Password (default None)
    ...                - keyfile (optional): Key file path (default None)
    ...
    ...                RETURNS: True if login succeeds, False otherwise.
    [Arguments]    ${device}    ${host}    ${port}    ${username}    ${password}    ${keyfile}
    Open Connection    ${host}    port=${port}    alias=${device}
    ${login_status}    Run Keyword If    '${keyfile}' != 'None'    Login With Public Key    ${username}    ${keyfile}
    ...    ELSE    Login    ${username}    ${password}
    RETURN    ${login_status}

Evaluate Reverse SSH Connection
    [Documentation]   Connects via SSH, sends SDM port when prompted, and waits for device prompt.
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - reverse_host (mandatory): SSH host/IP
    ...                - reverse_port (mandatory): SSH port
    ...                - sdm_port (mandatory): SDM port to send
    ...                - reverse_username (mandatory): Username
    ...                - reverse_keyfile (mandatory): Key file path
    ...                - timeout (optional): Timeout for connection (default 10 seconds)
    ...
    ...                RETURNS: True if login succeeds, False otherwise.
    [Arguments]    ${device}    ${revesre_host}    ${reverse_port}    ${sdm_port}    ${reverse_username}    ${reverse_keyfile}    ${timeout}=10 seconds
    Run Process    chmod    600    ${reverse_keyfile}
    Open Connection    ${revesre_host}    port=${reverse_port}    timeout=${timeout}    alias=${device}
    sleep    3
    Login With Public Key    ${reverse_username}    ${reverse_keyfile}
    Write    \n
    ${propmpt1}    Read Until    Enter port number
    Write    ${sdm_port}
    Write    \n 
    ${prompt2}    Read Until    /etc/insight/support# 
    ${login_status}    Should Contain    ${prompt2}    /etc/insight/support#
    RETURN    ${login_status}

SSH Close Access
    [Documentation]    Closes the SSH connection if open.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - host (mandatory): SSH host/IP
    ...
    ...                RETURNS: None
    [Arguments]    &{arguments}
    ${device}    Get From Dictionary    ${arguments}    device
    Switch Connection    ${device}
    ${ssh_status}    Run Keyword And Return Status    Close Connection
    Run Keyword If    not ${ssh_status}    Log    SSH Close Access failed for ${device}

SSH Write Command
    [Documentation]    Sends a command and returns output.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - command (mandatory): Command to send
    ...                - timeout (optional): Amount of time needs to wait to read output
    ...
    ...                RETURNS: Command output (string)
    [Arguments]    &{arguments}
    ${device}     Get From Dictionary    ${arguments}    device
    ${command}    Get From Dictionary    ${arguments}    command
    ${timeout}    Get From Dictionary    ${arguments}    timeout    default=1s
    Switch Connection    ${device}
    Write    ${command}
    ${output}    Read    delay=${timeout}
    RETURN    ${output}

SSH Write Command Only
    [Documentation]    Sends a command without reading output.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - command (mandatory): Command to send
    ...
    ...                RETURNS: None
    [Arguments]    &{arguments}
    ${device}    Get From Dictionary    ${arguments}    device
    ${command}   Get From Dictionary    ${arguments}    command
    Switch Connection    ${device}
    Write    ${command}

SSH Write until Expected Output
    [Documentation]    Sends a command and waits until expected output.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - command (mandatory): Command
    ...                - expected_output (mandatory): String to wait for
    ...                - timeout (optional): Timeout (default 5s)
    ...                - retry_interval (optional): Retry interval (default 1s)
    ...
    ...                RETURNS: True if success, False otherwise
    [Arguments]    &{arguments}
    ${device}           Get From Dictionary    ${arguments}    device
    ${command}          Get From Dictionary    ${arguments}    command
    ${expected_output}  Get From Dictionary    ${arguments}    expected_output
    ${timeout}          Get From Dictionary    ${arguments}    timeout           default=5s
    ${retry_interval}   Get From Dictionary    ${arguments}    retry_interval    default=1s
    Switch Connection    ${device}
    ${status}    Run Keyword And Return Status
    ...    Write Until Expected Output    ${command}\n    ${expected_output}    ${timeout}    ${retry_interval}
    RETURN    ${status}

SSH Write Multiple Commands
    [Documentation]    Executes multiple commands sequentially.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - commands (mandatory): `;`-separated commands
    ...                - output_format (optional): `dict` (default) or `last`
    ...
    ...                RETURNS: Dict {cmd: output} or last output
    [Arguments]    &{arguments}
    ${device}         Get From Dictionary    ${arguments}    device
    ${commands}       Get From Dictionary    ${arguments}    commands
    ${output_format}  Get From Dictionary    ${arguments}    output_format    default=dict
    Switch Connection    ${device}
    ${command_list}   Split String    ${commands}    ;
    &{outputs}        Create Dictionary
    FOR    ${command}    IN    @{command_list}
        ${command}    Strip String    ${command}
        ${output}     Execute Command    ${command}
        Set To Dictionary    ${outputs}    ${command}=${output}
    END
    Run Keyword If    '${output_format}' == 'dict'    Return From Keyword    ${outputs}
    ${last_output}    Get From Dictionary    ${outputs}    ${command}
    RETURN    ${last_output}

SSH Execute Command
    [Documentation]    Executes a command and optionally returns stdout, stderr, rc.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - command (mandatory): Command
    ...                - return_stdout (optional): Default True
    ...                - return_stderr (optional): Default False
    ...                - return_rc (optional): Default False
    ...
    ...                RETURNS: dict with requested outputs
    [Arguments]    &{arguments}
    ${device}          Get From Dictionary    ${arguments}    device
    ${command}         Get From Dictionary    ${arguments}    command
    ${return_stdout}   Get From Dictionary    ${arguments}    return_stdout    default=True
    ${return_stderr}   Get From Dictionary    ${arguments}    return_stderr    default=False
    ${return_rc}       Get From Dictionary    ${arguments}    return_rc        default=False
    Switch Connection    ${device}
    ${result}    Execute Command    ${command}    return_stdout=${return_stdout}    return_stderr=${return_stderr}    return_rc=${return_rc}
    RETURN    ${result}

SSH Execute Command in Background
    [Documentation]    Runs a command in background.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - command (mandatory): Command
    ...
    ...                RETURNS: Command ID or result depending on implementation
    [Arguments]    &{arguments}
    ${device}    Get From Dictionary    ${arguments}    device
    ${command}   Get From Dictionary    ${arguments}    command
    Switch Connection    ${device}
    ${output}    Start Command    ${command}
    RETURN    ${output}

SSH Write Command as Sudo
    [Documentation]    Sends a command prefixed with sudo for elevated execution; does not wait for result.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - command (mandatory): Command to run with sudo
    ...                - sudo_password (optional): Sudo password if required (default None)
    ...
    ...                RETURNS: Output string from command execution
    [Arguments]    &{arguments}
    ${device}          Get From Dictionary    ${arguments}    device
    ${command}         Get From Dictionary    ${arguments}    command
    ${sudo_password}   Get From Dictionary    ${arguments}    sudo_password    default=None
    Switch Connection    ${device}
    ${sudo_command}    Set Variable    echo '${sudo_password}' | sudo -S ${command}
    Write    ${sudo_command}
    ${output}    Read
    RETURN    ${output}

SSH Execute Command as Sudo
    [Documentation]    Executes a sudo command and waits for result.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - command (mandatory): Command to run with sudo
    ...                - sudo_password (optional): Sudo password if required (default None)
    ...                - return_stdout (optional): Whether to return stdout (default True)
    ...                - return_stderr (optional): Whether to return stderr (default False)
    ...                - return_rc (optional): Whether to return return code (default False)
    ...
    ...                RETURNS: Dict containing requested outputs
    [Arguments]    &{arguments}
    ${device}          Get From Dictionary    ${arguments}    device
    ${command}         Get From Dictionary    ${arguments}    command
    ${sudo_password}   Get From Dictionary    ${arguments}    sudo_password    default=None
    ${return_stdout}   Get From Dictionary    ${arguments}    return_stdout    default=True
    ${return_stderr}   Get From Dictionary    ${arguments}    return_stderr    default=False
    ${return_rc}       Get From Dictionary    ${arguments}    return_rc        default=False
    Switch Connection    ${device}
    ${result}    Execute Command    ${command}    sudo=True    sudo_password=${sudo_password}    return_stdout=${return_stdout}    return_stderr=${return_stderr}    return_rc=${return_rc}
    RETURN    ${result}

SSH Execute Command as Sudo in Background
    [Documentation]    Starts a sudo command in background mode without waiting for output.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - command (mandatory): Command to run with sudo
    ...                - sudo_password (optional): Sudo password if required (default None)
    ...
    ...                RETURNS: Background job handle or ID
    [Arguments]    &{arguments}
    ${device}          Get From Dictionary    ${arguments}    device
    ${command}         Get From Dictionary    ${arguments}    command
    ${sudo_password}   Get From Dictionary    ${arguments}    sudo_password    default=None
    Switch Connection    ${device}
    ${result}    Start Command    ${command}    sudo=True    sudo_password=${sudo_password}
    RETURN    ${result}

SSH Get File
    [Documentation]    Downloads a file from remote SSH host to local machine.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - remote_path (mandatory): Remote file path
    ...                - local_path (mandatory): Local save path
    ...
    ...                RETURNS: None
    [Arguments]    &{arguments}
    ${device}         Get From Dictionary    ${arguments}    device
    ${remote_path}    Get From Dictionary    ${arguments}    remote_path
    ${local_path}     Get From Dictionary    ${arguments}    local_path
    Switch Connection    ${device}
    Get File    ${remote_path}    ${local_path}

SSH Put File
    [Documentation]    Uploads a local file to remote SSH host.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - local_path (mandatory): Local file path
    ...                - remote_path (mandatory): Remote destination path
    ...
    ...                RETURNS: None
    [Arguments]    &{arguments}
    ${device}       Get From Dictionary    ${arguments}    device
    ${local_path}   Get From Dictionary    ${arguments}    local_path
    ${remote_path}  Get From Dictionary    ${arguments}    remote_path
    Switch Connection    ${device}
    Put File    ${local_path}    ${remote_path}

SSH Read
    [Documentation]    Reads data from SSH channel.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - delay (optional): Delay before read (default 0.5s)
    ...
    ...                RETURNS: Output string
    [Arguments]    &{arguments}
    ${device}    Get From Dictionary    ${arguments}    device
    ${delay}     Get From Dictionary    ${arguments}    delay    default=0.5s
    Switch Connection    ${device}
    ${output}    Read    delay=${delay}
    RETURN    ${output}

SSH Read Until
    [Documentation]    Reads until expected string found.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...                - expected (mandatory): String to wait for
    ...
    ...                RETURNS: Output string
    [Arguments]    &{arguments}
    ${device}    Get From Dictionary    ${arguments}    device
    ${expected}  Get From Dictionary    ${arguments}    expected
    Switch Connection    ${device}
    ${output}    Read Until    ${expected}
    RETURN    ${output}

SSH Read Background Command Output
    [Documentation]    Reads output of background command until completion.
    ...
    ...                INPUT:
    ...                - device (mandatory): Connection alias
    ...
    ...                RETURNS: Output string
    [Arguments]    &{arguments}
    ${device}    Get From Dictionary    ${arguments}    device
    Switch Connection    ${device}
    ${output}    Read Command Output
    RETURN    ${output}
