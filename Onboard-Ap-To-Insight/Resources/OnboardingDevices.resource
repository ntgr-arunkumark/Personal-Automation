*** Settings ***
Library           Process  ###NEED TO REMOVE DURING INTEGRATION
Library           XML
Library           Collections
Library           OperatingSystem
Library           String
Variables         ../AutomationYaml/SupportAlias.yaml
Variables         ../AutomationYaml/switchCommands.yaml

*** Keywords ***

############################# Target Keywords #############################
Onboard AP Device To Insight   
    [Arguments]     &{inputArguments}
    ${deviceName}    Get From Dictionary    ${inputArguments}     deviceName
    ${switchIP}    Set Variable    ${${deviceName}}[ipAddress]
    @{PoeList}    Get From Dictionary    ${inputArguments}     poePortNumberList
    
    # SSH into Switch and Enter Root mode    switchIP=${switchIP}  ##Working
    &{onboardingInfoDict}    Create Dictionary
    # SSH Open Access    &{inputArguments} ## check this one
    SSH Open Access    device=${deviceName}    host=${switchIP}    username=${${deviceName}}[ssh][username]    password=${${deviceName}}[ssh][password]
    FOR     ${poe}    IN     @{PoeList}
        ${OnboardingInfo}    Get Onboarding Information from LLDP    deviceName=${deviceName}    portNumber=${poe}
        Set To Dictionary    ${onboardingInfoDict}    ${poe}    ${OnboardingInfo}

    END
    Log    Onboarding Information: ${onboardingInfoDict}    WARN


############################# HIGH Level Keywords #############################

Get The Ethernet Port Speed From Testbed
    [Arguments]    &{inputArguments}
    ${deviceName}     Get From Dictionary    ${inputArguments}    deviceName
    ${portNumber}     Get From Dictionary     ${inputArguments}    portNumber

    ${deviceNameinfo}    Set Variable    ${deviceName}
    ${speedInfoDevice}    Get From Dictionary    ${${deviceNameinfo}}    LinkSpeed
    ${devicePortranges}     Get Dictionary Keys     ${speedInfoDevice}
    ${portSpeed}     Set Variable    ${FALSE}
    
    FOR    ${portInput}    IN    @{devicePortranges}
        ${portRange}    Get From Dictionary    ${speedInfoDevice}    ${portInput}
        ${parts}=    Split String    ${portRange}    -
        ${start}=    Convert To Number    ${parts[0]}
        ${end}=      Convert To Number    ${parts[1]}
        IF    ${start} <= ${portNumber} <= ${end}   
            ${portSpeed}     Set Variable     ${TRUE}
            Return From Keyword    ${EthernetSpeeds}[${portInput}]
        END
    END
    Run Keyword If    not ${portSpeed}      FAIL     Unable to get the valid speed alias from the preconfigured values.

############################# Low Level Keywords #############################

Get Onboarding Information from LLDP

    [Arguments]    &{inputArguments}

    ${deviceName}     Get From Dictionary    ${inputArguments}    deviceName
    ${portNumber}     Get From Dictionary     ${inputArguments}    portNumber

    ${deviceNameinfo}    Set Variable    ${deviceName}

    Check If Root Mode is Enabled in Switch    &{inputArguments}

    ${poeLinkSpeed}    Get The Ethernet Port Speed From Testbed    deviceName=${deviceName}    portNumber=${portNumber}

    #def build_command(self, command=None, os=None, arguments=None, flags=None, **kwargs):
    &{dictArguments}   Create Dictionary    portSpeed=${poeLinkSpeed}    portNumber=${portNumber}
    ${lldpNeighbourInterfaceCommand}    Build Command    lldpInterfaceNeighbor    linux    &{dictArguments}
    Log    lldpNeighbourInterfaceCommand: ${lldpNeighbourInterfaceCommand}    WARN
    
    ${lldpNeighbourInterfaceOutput}    SSH Write Command    device=${deviceName}    command=${lldpNeighbourInterfaceCommand}    timeout=5s
    Log    ${lldpNeighbourInterfaceOutput}   WARN
    
    ${system_name_line}=    Get Lines Containing String    ${lldpNeighbourInterfaceOutput}    System Name
    ${system_name_length}    Get Length    ${system_name_line}
    Run Keyword If    ${system_name_length} == 0    FAIL    Unable to find the System Name in the LLDP output for device: ${deviceName}

    ${port_id_line}=        Get Lines Containing String    ${lldpNeighbourInterfaceOutput}    Port ID
    ${mgmt_addr_line}=      Get Lines Containing String    ${lldpNeighbourInterfaceOutput}    Management address

    ${system_name}=    Split String    ${system_name_line}    System Name:    
    ${port_id}=        Split String    ${port_id_line}      Port ID:        
    ${mgmt_addr}=      Split String    ${mgmt_addr_line}    Management address:    

    ${system_name}=         Strip String    ${system_name}[1]
    ${port_id}=             Strip String    ${port_id}[1]      
    ${mgmt_addr}=           Strip String    ${mgmt_addr}[1]

    &{lldpInfo}    Create Dictionary    SerialNumber= ${system_name}    MacAddress=${port_id}    IPAddress=${mgmt_addr}
    Return From Keyword    &{lldpInfo}


# ${system_name_line}=    Get Line Containing String    ${output}    System Name
#     ${port_id_line}=        Get Line Containing String    ${output}    Port ID
#     ${mgmt_addr_line}=      Get Line Containing String    ${output}    Management address

#     ${system_name}=         Get Substring After    ${system_name_line}    System Name:
#     ${port_id}=             Get Substring After    ${port_id_line}      Port ID:
#     ${mgmt_addr}=           Get Substring After    ${mgmt_addr_line}    Management address:


Check If Root Mode is Enabled in Switch
    [Arguments]    &{inputArguments}

    Log    --- Inside "Check If Root Mode is Enabled in Switch" Keyword---

    ${deviceName}     Get From Dictionary    ${inputArguments}    deviceName
    ${switchInfo}    Set To Dictionary    ${${deviceName}}
    ${deviceSSHInfo}    Get From Dictionary    ${switchInfo}    ssh

    Log    switchInfo:${switchInfo}; deviceSSHInfo:${deviceSSHInfo}    WARN

    ${statusOutput}    SSH Write Command    device=${deviceName}    command="\n;\n"    timeout=4s
    ${sshRootPrompt}    Get From Dictionary    ${deviceSSHInfo}    rootPrompt

    ${rootPromptStatus}    Run Keyword and Return Status    Should Contain    ${statusOutput}    ${sshRootPrompt}
    # ${rootPromptStatus}    Set Variable    ${FALSE}    ###!!!!! REMOVE
    Run keyword If    not ${rootPromptStatus}    SSH into Switch and Enter Root mode    &{inputArguments}

SSH into Switch and Enter Root mode

    [Arguments]    &{inputArguments}

    Log    --- Inside "SSH into Switch and Enter Root mode" Keyword---

    ${deviceName}    Get From Dictionary    ${inputArguments}     deviceName
    ${retryCount}    Get From Dictionary    ${inputArguments}    retry    default=3

    ${switchInfo}    Set To Dictionary    ${${deviceName}}
    #SSHDevice Info:
    # ${aliasName}     Get From Dictionary    ${switchInfo}    deviceName
    ${hostIp}     Get From Dictionary    ${switchInfo}    ipAddress
    #SSH Info
    ${deviceSSHInfo}    Get From Dictionary    ${switchInfo}    ssh
    ${sshUsername}    Get From Dictionary    ${deviceSSHInfo}    username
    ${sshPassword}    Get From Dictionary    ${deviceSSHInfo}    password
    ${sshSudoPassword}    Get From Dictionary    ${deviceSSHInfo}    sudo_password

    ${sshRootPrompt}    Get From Dictionary    ${deviceSSHInfo}    rootPrompt

    # Log    switchInfo: ${switchInfo}; deviceSSHInfo:${deviceSSHInfo}; hostIp:${hostIp}    WARN
    # Return From Keyword    ${TRUE}    ###!!!!! REMOVE

    # ${args}=    Create Dictionary    device=${device}    host=${host}    username=${username}    password=${password}
    ${openSSH}    Run Keyword And Return Status    SSH Open Access     device=${deviceName}    host=${hostIp}     username=${sshUsername}    password=${sshPassword}
    Run Keyword If    not ${openSSH}     FAIL     UNABLE TO SSH INTO THE SWITCH TO ONBOARD THE DEVICE.
    
    #To Check if Root Prompt is enabled in switch device, if not it will enable the root prompt.
    FOR    ${retry}     IN RANGE    ${retryCount}
        
        ${statusOutput}    SSH Write Command    device=${deviceName}    command="\n;\n"    timeout=4s
        ${rootPromptStatus}    Run Keyword and Return Status    Should Contain    ${statusOutput}    ${sshRootPrompt}
        # If the root prompt is not found, it will retry the command
        # If     not ${rootPromptStatus}    Check For Password Prompt in SSH and Execute command    &{inputArguments}
        IF     not ${rootPromptStatus}

            ${writtenCmdOutput}    SSH Write Command    device=${deviceName}    command="enable"
            ${lowerCaseCmdOutput}     Convert to lower Case    ${writtenCmdOutput}
            #Check if the command output contains 'password' to handle case-insensitive password prompts
            ${status}    Run Keyword and Return Status    Should Contain    ${lowerCaseCmdOutput}    password  #since password can be case-insensitive
            Run Keyword If    ${status}    SSH Write Command     device=${deviceName}    command=${sshSudoPassword}

        END
        
        Exit For Loop If    ${rootPromptStatus}

    END

    Run Keyword If    not ${rootPromptStatus}    FAIL     Unable to enter into Root mode of device with IP: ${hostIp}
