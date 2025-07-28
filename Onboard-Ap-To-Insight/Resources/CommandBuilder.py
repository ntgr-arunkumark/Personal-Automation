import yaml
from string import Template
from robot.libraries.BuiltIn import BuiltIn


def _substitute_variables(text, kwargs, builtin):
    '''Substitute $variables using kwargs or Robot BuiltIn variables.'''
    if "$" not in text:
        return text

    template = Template(text)
    required_vars = {match[1] for match in Template.pattern.findall(text) if match[1]}

    final_values = {
        var: kwargs.get(var) or builtin.get_variable_value(f"${{{var}}}", default=None)
        for var in required_vars
    }

    missing = [var for var, val in final_values.items() if val is None]
    if missing:
        raise ValueError(f"Missing variable(s): {', '.join(missing)} for substitution in '{text}'")

    return template.substitute(**final_values)

def build_command(command=None, os=None, arguments=None, flags=None, **kwargs):
    '''
    Builds a shell command string.

    - If `arguments` or `flags` are given, it manually constructs the command and substitutes any $variables.
    - If not, it uses a template from commands.yaml and performs substitution.

    Args:
        command: Name of the command (e.g., "ping", "fping")
        os: Operating system (e.g., "linux", "mac")
        arguments: Dictionary of command arguments (e.g., {"c": 5})
        flags: List of command flags (e.g., ["g", "v"])
        kwargs: Additional variables used for substitution

    Returns:
        Full resolved command string.
    '''
    if not command:
        raise ValueError("Command name must be provided.")
    if not os:
        raise ValueError("OS must be provided.")

    # os = os.lower()
    arguments = arguments or {}
    flags = flags or []

    builtin = BuiltIn()

    # --- Case 1: Manual CLI construction ---
    if arguments or flags:
        return_command = [command]

        allowed_args = Commandarguments.get(command, {}).get(os)
        allowed_flags = Commandflags.get(command, {}).get(os)

        if allowed_args is None:
            builtin.log(f"No argument definition for '{command}' on '{os}'. Skipping validation.", level='WARN')
            allowed_args = []

        if allowed_flags is None:
            builtin.log(f"No flag definition for '{command}' on '{os}'. Skipping validation.", level='WARN')
            allowed_flags = []

        for arg, val in arguments.items():
            if arg not in allowed_args:
                builtin.log(f'Invalid argument "{arg}" for "{command}" on "{os}". Adding anyway.', level='WARN')
            prefix = "-" if len(arg) == 1 else "--"
            return_command.extend([f"{prefix}{arg}", str(val)])

        for flag in flags:
            if flag not in allowed_flags:
                builtin.log(f'Invalid flag "{flag}" for "{command}" on "{os}". Adding anyway.', level='WARN')
            prefix = "-" if len(flag) == 1 else "--"
            return_command.append(f"{prefix}{flag}")

        joined_command = " ".join(return_command)
        return _substitute_variables(joined_command, kwargs, builtin)

    # --- Case 2: Template-based command ---
    cmd_dict = builtin.get_variable_value("${" + command + "}", default=None)

    print(cmd_dict)

    if not cmd_dict:
        raise ValueError(f"Command '{command}' not found in Robot Framework variables. Ensure it is imported via 'Variables'.")
 
    cmd_template = cmd_dict.get(os)

    if not cmd_template:
        raise ValueError(f"Template for command '{command}' on OS '{os}' not found in commands.yaml.")

    return _substitute_variables(cmd_template, kwargs, builtin)