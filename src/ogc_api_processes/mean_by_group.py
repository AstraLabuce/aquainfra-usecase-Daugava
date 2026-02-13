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
Output file name: mean_by_group-xyz.csv

curl -X POST https://${PYSERVER}/processes/mean-by-group/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/mean-by-group/peri_conv.csv",
        "colnames_to_group_by": "longitude, latitude, Year_adj_generated, group_labels, HELCOM_ID",
        "colname_value": "transparen"
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
        self.job_id = 'nothing-yet'
        self.process_id = self.metadata["id"]
        self.image_name = "daugava-workflow-image:20250522"
        self.script_name = "mean_by_group.R"
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as config_file:
            config = json.load(config_file)
            self.download_dir = config["download_dir"].rstrip('/')
            self.download_url = config["download_url"].rstrip('/')
            self.docker_executable = config.get("docker_executable", "docker")

    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<MeanByGroupProcessor> {self.name}'

    def execute(self, data, outputs=None):

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

        # Quickly check whether the input data url is reachable
        requests.head(input_data_url).raise_for_status()

        # Where to store output data
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')
        # Output filename
        out_result_path = f'{output_dir}/mean_by_group_{self.job_id}.csv'
        out_result_url  = f'{output_url}/mean_by_group_{self.job_id}.csv'

        # Assemble arguments for R script:
        r_args = [
            input_data_url,
            in_cols_to_group_by,
            in_value_col,
            out_result_path
        ]

        # Run docker container
        returncode, stdout, stderr = docker_utils.run_docker_container(
            self.docker_executable,
            self.image_name,
            self.script_name,
            output_dir,
            self.job_id,
            r_args
        )

        if not returncode == 0:
            err_msg = 'Running docker container failed.'
            for line in stderr.split('\n'):
                if line.startswith('Error'):
                    err_msg = 'Running docker container failed: %s' % (line)
            raise ProcessorExecuteError(user_msg = err_msg)

        else:
            response_object = {
                "outputs": {
                    "mean_by_group": {
                        "title": self.metadata['outputs']['mean_by_group']['title'],
                        "description": self.metadata['outputs']['mean_by_group']['description'],
                        "href": out_result_url
                    }
                }
            }

            return 'application/json', response_object

