import subprocess
import logging
import os

LOGGER = logging.getLogger(__name__)


def run_docker_container(
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
        return result.returncode, stdout, stderr

    except subprocess.CalledProcessError as e:
        returncode = e.returncode
        stdout = e.stdout.decode()
        stderr = e.stderr.decode()
        LOGGER.error('Failed running docker container (exit code %s)' % returncode)
        return returncode, stdout, stderr

