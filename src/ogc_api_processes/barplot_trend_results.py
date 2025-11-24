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
        self.job_id = 'nothing-yet'
        self.process_id = self.metadata["id"]

    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<BarplotTrendResultsProcessor> {self.name}'

    def execute(self, data, outputs=None):
        # Get config
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)

        self.download_dir = configJSON["download_dir"]
        self.download_url = configJSON["download_url"]
        docker_executable = configJSON.get("docker_executable", "docker")

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
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')
        downloadfilename = 'barplot_image-%s.png' % self.job_id
        #downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename
        downloadpath = f'{output_dir}/{downloadfilename}'
        downloadlink = f'{output_url}/{downloadfilename}'

        # Run docker container
        returncode, stdout, stderr = run_docker_container(
            docker_executable,
            output_dir,
            input_data_url, 
            in_id_col, 
            in_test_value, 
            p_value,
            str(in_p_value_threshold),
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
        docker_executable,
        output_dir,
        input_data_url, 
        in_id_col, 
        in_test_value, 
        p_value, 
        in_p_value_threshold, 
        in_group, 
        download_dir, 
        outputFilename
    ):
    LOGGER.debug('Prepare running docker container')
    container_name = f'daugava-workflow-image_{os.urandom(5).hex()}'
    image_name = 'daugava-workflow-image:20250522'

    # Prepare container command

    # Define paths inside the container
    container_out = '/out'

    script = 'barplot_trend_results.R'

    # Mount volumes and set command
    docker_command = [
        docker_executable, "run", "--rm", "--name", container_name,
        "-v", f"{output_dir}:{container_out}",
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
