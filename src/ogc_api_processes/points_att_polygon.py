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
Output file name: "data_merged_with_regions-xyz.csv"

For Helcom data, you will need to accepts the conditions first:
https://maps.helcom.fi/website/MADS/download/?id=67d653b1-aad1-4af4-920e-0683af3c4a48

Long/lat are optional

curl -X POST https://${PYSERVER}/processes/points-att-polygon/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "regions": "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/points-att-polygon/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.zip",
        "colname_long": "long",
        "colname_lat": "lat",
        "input_data": "https://vm4072.kaj.pouta.csc.fi/ddas/oapif/collections/lva_secchi/items?f=json&limit=3000"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class PointsAttPolygonProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.job_id = 'nothing-yet'
        self.process_id = self.metadata["id"]
        self.image_name = "daugava-workflow-image:20250522"
        self.script_name = "points_att_polygon.R"
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as config_file:
            config = json.load(config_file)
            self.download_dir = config["download_dir"].rstrip('/')
            self.download_url = config["download_url"].rstrip('/')
            self.docker_executable = config.get("docker_executable", "docker")

    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<PointsAttPolygonProcessor> {self.name}'

    def execute(self, data, outputs=None):

        # Get user inputs
        in_regions_url = data.get('regions')
        in_dpoints_url = data.get('input_data')
        in_long_col_name = data.get('colname_long', 'long')
        in_lat_col_name = data.get('colname_lat', 'lat')

        # Check:
        if in_regions_url is None:
            raise ProcessorExecuteError('Missing parameter "regions". Please provide a URL to your input study area (as zipped shapefile).')
        if in_dpoints_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a URL to your input table.')

        # Quickly check whether the input data url is reachable
        requests.head(in_regions_url).raise_for_status()
        # This raised HTTP 500 in tests, maybe WFS do not respond to HTTP HEAD?
        #requests.head(in_dpoints_url).raise_for_status()

        # Where to store output data
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')
        # Output filename
        out_result_path = f'{output_dir}/data_merged_with_regions_{self.job_id}.csv'
        out_result_url  = f'{output_url}/data_merged_with_regions_{self.job_id}.csv'

        # Assemble arguments for R script:
        r_args = [
            in_regions_url,
            in_dpoints_url,
            in_long_col_name,
            in_lat_col_name,
            out_result_path
        ]

        # Run docker container
        returncode, stdout, stderr = docker_utils.run_docker_container(
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
                "data_merged_with_regions": {
                    "title": self.metadata['outputs']['data_merged_with_regions']['title'],
                    "description": self.metadata['outputs']['data_merged_with_regions']['description'],
                    "href": out_result_url
                }
            }
        }

        return 'application/json', response_object

