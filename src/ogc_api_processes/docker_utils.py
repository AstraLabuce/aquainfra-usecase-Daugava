import subprocess
import logging
import os

LOGGER = logging.getLogger(__name__)


def run_docker_container(
        LOGGER,
        docker_executable,
        image_name,
        script_name,
        output_dir,
        job_id,
        script_args
    ):

    LOGGER.debug('Prepare running docker container')

    # Create container name
    # Note: Only [a-zA-Z0-9][a-zA-Z0-9_.-] are allowed
    #container_name = "%s_%s" % (image_name.split(':')[0], os.urandom(5).hex())
    container_name = "%s_%s" % (image_name.split(':')[0], job_id)
    LOGGER.debug(f'Image: {image_name}, container: {container_name})')

    # Define paths inside the container
    container_out = '/out'

    # Replace host out with container out:
    LOGGER.debug('Script args (before sanitizing): %s' % script_args)

    # Sanitizing args: They have to be strings to be passed to docker-run via
    # subprocess library, and paths have to be modified to match the bind-mounted
    # paths inside the container:
    sanitized_args = []
    for arg in script_args:

        # For files, replace the host path with the in-container path:
        if isinstance(arg, str) and output_dir is not None and output_dir in arg:
            newarg = arg.replace(output_dir, container_out)

        # R scripts may be more familiar with receiving "null" than "None"
        # But they still have to parse them to a proper NULL data type.
        elif arg == 'None' or arg is None:
            newarg = 'null'

        # In any case, the newarg has to be a string:
        else:
            newarg = str(arg)

        # All arguments have to be added to the new list:
        sanitized_args.append(newarg)

    # Assemble docker command:
    docker_command = [
        docker_executable, "run", "--rm", "--name", container_name,
        "-v", f"{output_dir}:{container_out}",
        "-e", f"R_SCRIPT={script_name}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
    ]
    docker_command = docker_command + sanitized_args

    LOGGER.debug('Docker command: %s' % docker_command)
    
    # Run container
    try:
        LOGGER.debug('Start running docker container')
        result = subprocess.run(docker_command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout = result.stdout.decode()
        stderr = result.stderr.decode()
        LOGGER.debug('Finished running docker container')
        log_docker_output(LOGGER, stdout, stderr)
        return result.returncode, stdout, stderr, "no error"

    except subprocess.CalledProcessError as e:
        returncode = e.returncode
        stdout = e.stdout.decode()
        stderr = e.stderr.decode()
        LOGGER.error('Failed running docker container (exit code %s)' % returncode)
        log_docker_output(LOGGER, stdout, stderr)
        user_err_msg = get_R_error_message_from_docker_stderr(stderr)
        return returncode, stdout, stderr, user_err_msg



def log_docker_output(LOGGER, stdout, stderr):

    for line in stdout.split('\n'):
        if not line: continue
        LOGGER.debug('Docker stdout: %s' % line.strip())
        # output of print() in R-script

    for line in stderr.split('\n'):
        if not line: continue
        LOGGER.debug('Docker stderr: %s' % line.strip())
        # output of message() in R-script




def get_R_error_message_from_docker_stderr(stderr, log_all_lines = False):
    '''
    We would like to return meaningful messages to users. For example, by
    printing ALL stderr lines, we get the following:

    ERROR - Docker stderr: Error in if (zz[which.max(zz)] < minpts) stop("All species do not have enough data after removing missing values and duplicates.") : 
    ERROR - Docker stderr:   argument is of length zero
    ERROR - Docker stderr: Calls: pred_extract
    ERROR - Docker stderr: Execution halted

    ERROR - Docker stderr: Error in pred_extract(data = speciesfiltered, raster = worldclim, lat = in_colname_lat,  : 
    ERROR - Docker stderr:   All species do not have enough data after removing missing values and duplicates.
    ERROR - Docker stderr: Execution halted

    Now, how to capture the meaningful part of that, which we want to return
    to the user? Here is a first attempt:
    '''

    user_err_msg = ""
    error_on_previous_line = False
    colon_on_previous_line = False
    for line in stderr.split('\n'):

        # Skip empty lines:
        if not line:
            continue

        # Print all non-empty lines to log:
        if log_all_lines:
            LOGGER.error('Docker stderr: %s' % line)

        # R error messages may start with the word "Error"
        if line.startswith("Error"):
            #LOGGER.debug('### Found explicit error line: %s' % line.strip())
            user_err_msg += line.strip()
            error_on_previous_line = True

        # When R error messages are continued on another line, they may be
        # indented by two spaces.
        elif line.startswith("  ") and error_on_previous_line:
            #LOGGER.debug('### Found indented line following an error: %s' % line.strip())
            user_err_msg += " "+line.strip()
            error_on_previous_line = True

        # When R error messages end with a colon, they will be continued on
        # the next line, independently of their indentation I guess!
        elif colon_on_previous_line and error_on_previous_line:
            #LOGGER.debug('### Found line following a colon: %s' % line.strip())
            user_err_msg += " "+line.strip()
            error_on_previous_line = True

        else:
            #LOGGER.debug('### Do not pass back to user: %s' % line.strip())
            error_on_previous_line = False

        # Remember whether this line ended with a colon, indicating that the
        # next line will continue with the error message:
        colon_on_previous_line = False
        if line.strip().endswith(":"):
            #LOGGER.debug('### Found a colon, next line will still be error!')
            colon_on_previous_line = True

    return user_err_msg

