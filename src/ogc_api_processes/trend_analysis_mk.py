import logging
import subprocess
import json
import os
from pathlib import Path
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''

Output file name: trend_analysis_results-xyz.csv


curl --location 'http://localhost:5000/processes/trend-analysis-mk/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aqua.igb-berlin.de/download/trend_analysis_results-c66cecda-9501-11ef-aad4-8935a9f30073.csv",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "colname_time": "Year_adj_generated",
        "colname_value": "transparency_m"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class TrendAnalysisMkProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<TrendAnalysisMkProcessor> {self.name}'

    def execute(self, data, outputs=None):

        # Get config
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["download_url"]
        docker_executable = configJSON.get("docker_executable", "docker")

        # User inputs
        in_data_url = data.get('input_data') # or selected_interpolated.csv ?
        in_rel_cols = data.get('colnames_relevant')
        in_time_colname = data.get('colname_time') # 'year'
        in_value_colname = data.get('colname_value') # 'value'

        # Check
        if in_data_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a URL to your input data.')
        if in_rel_cols is None:
            raise ProcessorExecuteError('Missing parameter "colnames_relevant". Please provide column name(s).')
        if in_time_colname is None:
            raise ProcessorExecuteError('Missing parameter "colname_time". Please provide a column name.')
        if in_value_colname is None:
            raise ProcessorExecuteError('Missing parameter "colname_value". Please provide a column name.')

        # Where to store output data
        downloadfilename = 'trend_analysis_results-%s.csv' % self.my_job_id # or selected_interpolated.csv ?
        #downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        returncode, stdout, stderr = run_docker_container(
            docker_executable,
            in_data_url, 
            in_rel_cols, 
            in_time_colname, 
            in_value_colname,
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
            # Create download link:
            downloadlink = own_url.rstrip('/')+os.sep+"out"+os.sep+downloadfilename

            # Return link to file:
            response_object = {
                "outputs": {
                    "trend_analysis_results": {
                        "title": self.metadata['outputs']['trend_analysis_results']['title'],
                        "description": self.metadata['outputs']['trend_analysis_results']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

def run_docker_container(
        docker_executable,
        in_data_url, 
        in_rel_cols, 
        in_time_colname, 
        in_value_colname,
        download_dir, 
        outputFilename
    ):
    LOGGER.debug('Prepare running docker container')
    container_name = f'daugava-workflow-image_{os.urandom(5).hex()}'
    image_name = 'daugava-workflow-image'

    # Prepare container command

    # Define paths inside the container
    container_out = '/out'

    # Define local paths
    local_out = os.path.join(download_dir, "out")

    # Ensure directories exist
    os.makedirs(local_out, exist_ok=True)

    script = 'trend_analysis_mk.R'

    # Mount volumes and set command
    docker_command = [
        docker_executable, "run", "--rm", "--name", container_name,
        "-v", f"{local_out}:{container_out}",
        "-e", f"R_SCRIPT={script}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
        in_data_url, 
        in_rel_cols,  
        in_time_colname,  
        in_value_colname,
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
