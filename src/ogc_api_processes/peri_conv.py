import logging
import json
import os
import requests
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
# daugava repo has hyphen in it, so we cannot import it in the normal python way:
#from pygeoapi.process.aquainfra-usecase-Daugava.src.ogc_api_processes.docker_utils import run_docker_container
import importlib
docker_utils = importlib.import_module("pygeoapi.process.aquainfra-usecase-Daugava.src.ogc_api_processes.docker_utils")


'''
Output file name: peri_conv-xyz.csv

curl -X POST https://${PYSERVER}/processes/peri-conv/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/points-att-polygon/out/data_merged_with_regions-f013320a-cf6c-11f0-98ef-fa163e42fba0.csv",
        "colname_date": "visit_date",
        "group_to_periods": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "period_labels": "winter,spring,summer,autumn",
        "year_starts_at_dec1": true,
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
        self.job_id = 'nothing-yet'
        self.process_id = self.metadata["id"]
        self.image_name = "daugava-workflow-image:20260217-8b74622"
        self.script_name = "peri_conv.R"
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as config_file:
            config = json.load(config_file)
            self.download_dir = config["download_dir"].rstrip('/')
            self.download_url = config["download_url"].rstrip('/')
            self.docker_executable = config.get("docker_executable", "docker")

    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<PeriConvProcessor> {self.name}'

    def execute(self, data, outputs=None):

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

        # Make string from boolean, otherwise it fails:
        year_starts_at_dec1 = 'true' if year_starts_at_dec1 else 'false'

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

        # Quickly check whether the input data url is reachable
        requests.head(input_data_url).raise_for_status()

        # Where to store output data
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')
        out_result_path = f'{output_dir}/peri_conv_{self.job_id}.csv'
        out_result_url  = f'{output_url}/peri_conv_{self.job_id}.csv'

        # Assemble arguments for R script:
        r_args = [
            input_data_url,
            date_col_name,
            group_to_periods,
            period_labels,
            date_format,
            year_starts_at_dec1,
            out_result_path
        ]

        # Run docker container
        returncode, stdout, stderr, user_err_msg = docker_utils.run_docker_container(
            LOGGER,
            self.docker_executable,
            self.image_name,
            self.script_name,
            output_dir,
            self.job_id,
            r_args
        )

        # Handle errors:
        if not returncode == 0:
            user_err_msg = "no message" if len(user_err_msg) == 0 else user_err_msg
            err_msg = f'Running docker container failed: {user_err_msg}'
            raise ProcessorExecuteError(user_msg = err_msg)

        # Return link to file:
        response_object = {
            "outputs": {
                "data_grouped_by_date": {
                    "title": self.metadata['outputs']['data_grouped_by_date']['title'],
                    "description": self.metadata['outputs']['data_grouped_by_date']['description'],
                    "href": out_result_url
                }
            }
        }

        return 'application/json', response_object

