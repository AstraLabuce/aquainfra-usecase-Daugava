import logging
import subprocess
import json
import os
import requests
from urllib.parse import urlparse
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''

Output file name: barplot_image-xyz.png

curl --location 'http://localhost:5000/processes/barplot-trend-results/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://testserver.de/download/trend_analysis_results.csv",
        "colname_id": "HELCOM_ID",
        "colname_test_value": "Tau_Value",
        "colname_p_value": "P_Value",
        "p_value_threshold": "0.05",
        "colname_group": "period"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class BarplotTrendResultsProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<BarplotTrendResultsProcessor> {self.name}'

    def execute(self, data, outputs=None):
        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]

        # User inputs
        input_data_url = data.get('input_data')
        in_id_col = data.get('colname_id') # 'polygon_id'
        in_test_value = data.get('colname_test_value') # default was: Tau_Value
        p_value = data.get('colname_p_value') # 'p_value'
        in_p_value_threshold = data.get('p_value_threshold') # '0.05'
        in_group = data.get('colname_group') # default was: season, or group

        # Check user inputs
        if input_data_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a URL to your input data.')
        if in_id_col is None:
            raise ProcessorExecuteError('Missing parameter "colname_id". Please provide a column name.')
        if in_test_value is None:
            raise ProcessorExecuteError('Missing parameter "colname_test_value". Please provide a column name.')
        if p_value is None:
            raise ProcessorExecuteError('Missing parameter "colname_p_value". Please provide a column name.')
        if in_p_value_threshold is None:
            raise ProcessorExecuteError('Missing parameter "p_value_threshold". Please provide a column name.')
        if in_group is None:
            raise ProcessorExecuteError('Missing parameter "colname_group". Please provide a column name.')

        # Where to store output data
        downloadfilename = 'barplot_image-%s.png' % self.my_job_id
        #downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        returncode, stdout, stderr = run_docker_container(
            input_data_url, 
            in_id_col, 
            in_test_value, 
            p_value,
            in_p_value_threshold,
            in_group, 
            download_dir, 
            downloadfilename
        )

        if not returncode == 0:
            err_msg = 'Running docker container failed.'
            for line in stderr.split('\n'):
                if line.startswith('Error'):
                    err_msg = 'Running docker container failed: %s' % (line)
            raise ProcessorExecuteError(user_msg = err_msg)

        else:
            # Create download link:
            downloadlink = own_url.rstrip('/')+os.sep+downloadfilename

            # Return link to file:
            response_object = {
                "outputs": {
                    "barplot_image": {
                        "title": self.metadata['outputs']['barplot_image']['title'],
                        "description": self.metadata['outputs']['barplot_image']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object


def run_docker_container(
        input_data_url, 
        in_id_col, 
        in_test_value, 
        p_value, 
        in_p_value_threshold, 
        in_group, 
        download_dir, 
        outputFilename
    ):
    LOGGER.debug('Start running docker container')
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

    script = 'barplot_trend_results.R'

    # Mount volumes and set command
    docker_command = [
        "sudo", "docker", "run", "--rm", "--name", container_name,
        "-v", f"{local_in}:{container_in}",
        "-v", f"{local_out}:{container_out}",
        "-e", f"R_SCRIPT={script}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
        input_data_url, 
        in_id_col,  
        in_test_value,  
        p_value,
        in_p_value_threshold,
        in_group,
        f"{container_out}/{outputFilename}"  # Output filename
    ]
    
    # Run container
    try:
        result = subprocess.run(docker_command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout = result.stdout.decode()
        stderr = result.stderr.decode()
        return result.returncode, stdout, stderr

    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout.decode(), e.stderr.decode()