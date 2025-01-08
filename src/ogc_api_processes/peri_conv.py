import logging
import subprocess
import json
import os
from pathlib import Path
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
Output file name: peri_conv-xyz.csv

curl --location 'http://localhost:5000/processes/peri-conv/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aqua.igb-berlin.de/download/data_merged_with_regions-50af6b5e-9500-11ef-aad4-8935a9f30073.csv",
        "colname_date": "visit_date",
        "group_to_periods": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "period_labels": "winter,spring,summer,autumn",
        "year_starts_at_dec1": "True",
        "date_format": "y/m/d"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class PeriConvProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<PeriConvProcessor> {self.name}'

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
        date_col_name = data.get('colname_date') # e.g. visit_date
        group_to_periods = data.get('group_to_periods', 'Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30')
        period_labels = data.get('period_labels', 'winter,spring,summer,autumn')
        year_starts_at_dec1 = data.get('year_starts_at_dec1', True)
        date_format = data.get('date_format', 'y-m-d') # '%Y-%m-%d'

        # Check
        if input_data_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a URL to your input table.')
        if date_col_name is None:
            raise ProcessorExecuteError('Missing parameter "colname_date". Please provide a column name.')

        # Parse date format: y-m-d to %Y-%m-%d
        date_format = date_format.lower()
        tmp = ''
        for char in date_format:
            if char == 'y':
                tmp += '%Y'
            elif char == 'm':
                tmp += '%m'
            elif char == 'd':
                tmp += '%d'
            else:
                tmp += char
        LOGGER.debug('Replaced date format "%s" by "%s"!' % (date_format, tmp))
        date_format = tmp

        # Where to store output data
        downloadfilename = 'peri_conv-%s.csv' % self.my_job_id
        #downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        returncode, stdout, stderr = run_docker_container(
            docker_executable,
            input_data_url, 
            date_col_name, 
            group_to_periods, 
            period_labels,
            year_starts_at_dec1,
            date_format, 
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
                    "data_grouped_by_date": {
                        "title": self.metadata['outputs']['data_grouped_by_date']['title'],
                        "description": self.metadata['outputs']['data_grouped_by_date']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object


def run_docker_container(
        docker_executable,
        input_data_url, 
        date_col_name, 
        group_to_periods, 
        period_labels, 
        year_starts_at_dec1, 
        date_format, 
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

    script = 'peri_conv.R'

    # Mount volumes and set command
    docker_command = [
        docker_executable, "run", "--rm", "--name", container_name,
        "-v", f"{local_in}:{container_in}",
        "-v", f"{local_out}:{container_out}",
        "-e", f"R_SCRIPT={script}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
        input_data_url, 
        date_col_name,  
        group_to_periods,  
        period_labels,
        date_format,
        year_starts_at_dec1,
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
