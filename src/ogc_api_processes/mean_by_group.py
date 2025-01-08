import logging
import subprocess
import json
import os
from pathlib import Path
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
Output file name: mean_by_group-xyz.csv

curl --location 'http://localhost:5000/processes/mean-by-group/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aqua.igb-berlin.de/download/peri_conv-e53a2f66-9500-11ef-aad4-8935a9f30073.csv",
        "colnames_to_group_by": "longitude, latitude, Year_adj_generated, group_labels, HELCOM_ID",
        "colname_value": "transparency_m"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class MeanByGroupProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<MeanByGroupProcessor> {self.name}'

    def execute(self, data, outputs=None):

        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]
        docker_executable = configJSON.get("docker_executable", "docker")

        # Get user inputs
        input_data_url = data.get('input_data')
        in_cols_to_group_by = data.get('colnames_to_group_by')  # Fetch the value
        if in_cols_to_group_by:  # Check if it exists
            in_cols_to_group_by = in_cols_to_group_by.replace(" ", "")  # Remove all spaces

        in_value_col = data.get('colname_value') # "value", default was: "transparency_m"

        # Check:
        if input_data_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a URL to your input data.')
        if in_cols_to_group_by is None:
            raise ProcessorExecuteError('Missing parameter "colnames_to_group_by". Please provide column name(s).')
        if in_value_col is None:
            raise ProcessorExecuteError('Missing parameter "in_value_col". Please provide a column name.')

        # Where to store output data
        downloadfilename = 'mean_by_group-%s.csv' % self.my_job_id # or seasonal_means.csv?
        #downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        returncode, stdout, stderr = run_docker_container(
            docker_executable,
            input_data_url, 
            in_cols_to_group_by, 
            in_value_col, 
            download_dir, 
            downloadfilename
        )

        # print R stderr/stdout to debug log:
        for line in stdout.split("\n"):
            if not len(line.strip()) == 0:
                LOGGER.debug('R stdout: %s' % line)

        for line in stderr.split("\n"):
            if not len(line.strip()) == 0:
                LOGGER.debug('R stderr: %s' % line)

        if not returncode == 0:
            err_msg = 'Running docker container failed.'
            for line in stderr.split('\n'):
                if line.startswith('Error'):
                    err_msg = 'Running docker container failed: %s' % (line)
            raise ProcessorExecuteError(user_msg = err_msg)

        else:
            downloadlink = own_url.rstrip('/')+os.sep+"out"+os.sep+downloadfilename
            response_object = {
                "outputs": {
                    "mean_by_group": {
                        "title": self.metadata['outputs']['mean_by_group']['title'],
                        "description": self.metadata['outputs']['mean_by_group']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

def run_docker_container(
        docker_executable,
        input_data_url, 
        in_cols_to_group_by, 
        in_value_col, 
        download_dir, 
        outputFilename
    ):
    LOGGER.debug('Prepare running docker container')
    container_name = f'daugava-workflow-image_{os.urandom(5).hex()}'
    image_name = 'daugava-workflow-image'

    # Prepare container command

    # Define paths inside the container
    container_in = '/in'
    container_out = '/out'

    # Define local paths
    local_in = os.path.join(download_dir, "in")
    local_out = os.path.join(download_dir, "out")

    # Ensure directories exist
    os.makedirs(local_in, exist_ok=True)
    os.makedirs(local_out, exist_ok=True)

    script = 'mean_by_group.R'

    # Mount volumes and set command
    docker_command = [
        docker_executable, "run", "--rm", "--name", container_name,
        "-v", f"{local_in}:{container_in}",
        "-v", f"{local_out}:{container_out}",
        "-e", f"R_SCRIPT={script}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
        input_data_url, 
        in_cols_to_group_by,  
        in_value_col,  
        f"{container_out}/{outputFilename}"  # Output filename
    ]

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
        LOGGER.debug('Failed running docker container')
        return e.returncode, e.stdout.decode(), e.stderr.decode()
