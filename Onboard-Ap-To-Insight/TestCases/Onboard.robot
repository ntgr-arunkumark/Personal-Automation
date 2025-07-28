*** Settings ***
Resource           ../Resources/LoadResource.resource
Variables          Onboard.yaml
Variables          testbedConfigs.yaml

*** Test Cases ***

Trial1 - Onboard with the specific POE Port number
    
    # Onboard AP Device To Insight    &{OnboardingArguments}
    Onboard AP Device To Insight    &{OnboardingArguments}

# Onboard AP Device Trial1
#     [Documentation]    Trial1 - Onboard with the specific POE Port number
#     [Tags]    OnboardingDevices
#     [Setup]    Create Testbed Configurations

#     # Load the testbed configurations
#     ${testbedConfig}    Get Testbed Configurations

#     # Prepare the input arguments for onboarding
#     &{OnboardingArguments}    Create Dictionary
#     ...   switchIP=${testbedConfig}[switchIP]
#     ...   poePortNumberList=${testbedConfig}[poePortNumberList]

#     # Log the onboarding arguments for debugging
#     Log To Console    Onboarding Arguments: ${OnboardingArguments}

#     # Execute the onboarding keyword with the prepared arguments



# *** Keywords ***
# Get Testbed Configurations
#     # TODO: implement keyword "Get Testbed Configurations".
#     Fail    Not Implemented


# Create Testbed Configurations
#     # TODO: implement keyword "Create Testbed Configurations".
#     Fail    Not Implemented

