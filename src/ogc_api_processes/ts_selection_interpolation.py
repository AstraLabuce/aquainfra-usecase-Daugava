import logging
import subprocess
import json
import os
from pathlib import Path
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''

Output file name: interpolated_time_series-xyz.csv

curl -X POST https://${PYSERVER}/processes/ts-selection-interpolation/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/ts-selection-interpolation/mean_by_group.csv",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "missing_threshold_percentage": 60,
        "colname_year": "Year_adj_generated",
        "colname_value": "transparen",
        "min_data_point": 5
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
        self.job_id = 'nothing-yet'
        self.process_id = self.metadata["id"]
        self.image_name = "daugava-workflow-image:20250522"
        self.script_name = "ts_selection_interpolation.R"
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as config_file:
            config = json.load(config_file)
            self.download_dir = config["download_dir"].rstrip('/')
            self.download_url = config["download_url"].rstrip('/')
            self.docker_executable = config.get("docker_executable", "docker")

    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<TsSelectionInterpolationProcessor> {self.name}'

    def execute(self, data, outputs=None):

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
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')
        downloadfilename = 'interpolated_time_series-%s.csv' % self.job_id # or selected_interpolated.csv ?
        downloadlink = f'{output_url}/{downloadfilename}'

        # Run docker container
        returncode, stdout, stderr = run_docker_container(
            self.docker_executable,
            self.image_name,
            self.script_name,
            output_dir,
            self.job_id,
            in_data_url, 
            in_rel_cols, 
            str(in_missing_threshold_percentage),
            in_year_colname,
            in_value_colname,
            str(in_min_data_point),
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
        image_name,
        script_name,
        output_dir,
        job_id,
        in_data_url, 
        in_rel_cols, 
        in_missing_threshold_percentage, 
        in_year_colname, 
        in_value_colname, 
        in_min_data_point, 
        outputFilename
    ):
    LOGGER.debug('Will use this image: %s' % image_name)

    # Create container name
    # Note: Only [a-zA-Z0-9][a-zA-Z0-9_.-] are allowed
    #container_name = "%s_%s" % (image_name.split(':')[0], os.urandom(5).hex())
    container_name = "%s_%s" % (image_name.split(':')[0], job_id)
    LOGGER.debug(f'Prepare running docker (image {image_name}, container: {container_name})')

    # Define paths inside the container
    container_out = '/out'

    # Mount volumes and set command
    docker_command = [
        docker_executable, "run", "--rm", "--name", container_name,
        "-v", f"{download_dir}:{container_out}",
        "-e", f"R_SCRIPT={script_name}",  # Set the R_SCRIPT environment variable
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
