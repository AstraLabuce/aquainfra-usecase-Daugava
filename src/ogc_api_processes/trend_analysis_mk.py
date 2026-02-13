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

Output file name: trend_analysis_results-xyz.csv

curl -X POST https://${PYSERVER}/processes/trend-analysis-mk/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/ts-selection-interpolation/out/interpolated_time_series-8c61e7b0-0845-11f1-a4fe-fa163e42fba0.csv",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "colname_time": "Year_adj_generated",
        "colname_value": "transparen"
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
        self.job_id = 'nothing-yet'
        self.process_id = self.metadata["id"]
        self.image_name = "daugava-workflow-image:20250522"
        self.script_name = "trend_analysis_mk.R"
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as config_file:
            config = json.load(config_file)
            self.download_dir = config["download_dir"].rstrip('/')
            self.download_url = config["download_url"].rstrip('/')
            self.docker_executable = config.get("docker_executable", "docker")

    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<TrendAnalysisMkProcessor> {self.name}'

    def execute(self, data, outputs=None):

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

        # Quickly check whether the input data url is reachable
        requests.head(in_data_url).raise_for_status()


        # Where to store output data
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')
        # Output filename
        out_result_path = f'{output_dir}/trend_analysis_results_{self.job_id}.csv'
        out_result_url  = f'{output_url}/trend_analysis_results_{self.job_id}.csv'

        # Assemble arguments for R script:
        r_args = [
            in_data_url,
            in_rel_cols,
            in_time_colname,
            in_value_colname,
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

            # Return link to file:
            response_object = {
                "outputs": {
                    "trend_analysis_results": {
                        "title": self.metadata['outputs']['trend_analysis_results']['title'],
                        "description": self.metadata['outputs']['trend_analysis_results']['description'],
                        "href": out_result_url
                    }
                }
            }

            return 'application/json', response_object

