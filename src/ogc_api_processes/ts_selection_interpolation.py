import logging
import subprocess
import json
import os
from pathlib import Path
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''

Output file name: interpolated_time_series-xyz.csv


curl --location 'http://localhost:5000/processes/ts-selection-interpolation/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aqua.igb-berlin.de/download/mean_by_group-58327a2c-8fb2-11ef-aad4-8935a9f30073.csv",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "missing_threshold_percentage": "40",
        "colname_year": "Year_adj_generated",
        "colname_value": "transparency_m",
        "min_data_point": "10"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class TsSelectionInterpolationProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nnothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<TsSelectionInterpolationProcessor> {self.name}'

    def execute(self, data, outputs=None):

        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]
        docker_executable = configJSON.get("docker_executable", "docker")

        # Get user inputs
        in_data_url = data.get('input_data')
        in_rel_cols = data.get('colnames_relevant')
        in_missing_threshold_percentage = data.get('missing_threshold_percentage') # 30.0
        in_year_colname = data.get('colname_year') # 'Year'
        in_value_colname = data.get('colname_value') # 'value'
        in_min_data_point = data.get('min_data_point') # 10

        # Checks
        if in_data_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a URL to your input table.')
        if in_rel_cols is None:
            raise ProcessorExecuteError('Missing parameter "in_rel_cols". Please provide a value.')
        if in_missing_threshold_percentage is None:
            raise ProcessorExecuteError('Missing parameter "in_missing_threshold_percentage". Please provide a value.')
        if in_year_colname is None:
            raise ProcessorExecuteError('Missing parameter "colname_year". Please provide a column name.')
        if in_value_colname is None:
            raise ProcessorExecuteError('Missing parameter "colname_value". Please provide a column name.')
        if in_min_data_point is None:
            raise ProcessorExecuteError('Missing parameter "min_data_point". Please provide a value.')

        # Where to store output data
        downloadfilename = 'interpolated_time_series-%s.csv' % self.my_job_id # or selected_interpolated.csv ?
        #downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        returncode, stdout, stderr = run_docker_container(
            docker_executable,
            in_data_url, 
            in_rel_cols, 
            in_missing_threshold_percentage, 
            in_year_colname,
            in_value_colname,
            in_min_data_point, 
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
            downloadlink = own_url.rstrip('/')+os.sep+"out"+os.sep+downloadfilename
            response_object = {
                "outputs": {
                    "data_grouped_by_date": {
                        "title": self.metadata['outputs']['interpolated_time_series']['title'],
                        "description": self.metadata['outputs']['interpolated_time_series']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object


def run_docker_container(
        docker_executable,
        in_data_url, 
        in_rel_cols, 
        in_missing_threshold_percentage, 
        in_year_colname, 
        in_value_colname, 
        in_min_data_point, 
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

    script = 'ts_selection_interpolation.R'

    # Mount volumes and set command
    docker_command = [
        docker_executable, "run", "--rm", "--name", container_name,
        "-v", f"{local_in}:{container_in}",
        "-v", f"{local_out}:{container_out}",
        "-e", f"R_SCRIPT={script}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
        in_data_url, 
        in_rel_cols,  
        in_missing_threshold_percentage,  
        in_year_colname,
        in_value_colname,
        in_min_data_point,
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