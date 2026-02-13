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
Output file name: map_trends_static-xyz.png

curl -X POST https://${PYSERVER}/processes/map-trends-static/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "regions": "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/points-att-polygon/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.zip",
        "input_data": "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/trend-analysis-mk/out/trend_analysis_results-1a7b73d8-0848-11f1-b387-fa163e42fba0.csv",
        "colname_id_trend": "polygon_id",
        "colname_region_id": "HELCOM_ID",
        "colname_group": "period",
        "colname_p_value": "P_Value",
        "p_value_threshold": 0.05
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class MapTrendsStaticProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.job_id = 'nothing-yet'
        self.process_id = self.metadata["id"]
        self.image_name = "daugava-workflow-image:20250522"
        self.script_name = "map_trends_static.R"
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as config_file:
            config = json.load(config_file)
            self.download_dir = config["download_dir"].rstrip('/')
            self.download_url = config["download_url"].rstrip('/')
            self.docker_executable = config.get("docker_executable", "docker")

    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def execute(self, data, outputs=None):

        # User inputs
        in_shp_url = data.get('regions') # 'https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip')
        in_trend_results_url = data.get('input_data')
        in_id_trend_col = data.get('colname_id_trend') # default was: polygon_id, id
        in_id_shp_col = data.get('colname_region_id') # default was: HELCOM_ID, id
        in_group = data.get('colname_group') # default was: season, group
        in_p_value_threshold = data.get('p_value_threshold') # 0.05
        in_p_value_col = data.get('colname_p_value') # p_Value

        # Check user inputs
        if in_shp_url is None:
            raise ProcessorExecuteError('Missing parameter "regions". Please provide a URL to your input data.')
        if in_trend_results_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a column name.')
        if in_id_trend_col is None:
            raise ProcessorExecuteError('Missing parameter "colname_id_trend". Please provide a column name.')
        if in_id_shp_col is None:
            raise ProcessorExecuteError('Missing parameter "colname_region_id". Please provide a column name.')
        if in_group is None:
            raise ProcessorExecuteError('Missing parameter "colname_group". Please provide a column name.')
        if in_p_value_threshold is None:
            raise ProcessorExecuteError('Missing parameter "p_value_threshold". Please provide a value.')
        if in_p_value_col is None:
            raise ProcessorExecuteError('Missing parameter "colname_p_value". Please provide a column name.')

        # Quickly check whether the input data url is reachable
        requests.head(in_shp_url).raise_for_status()
        requests.head(in_trend_results_url).raise_for_status()

        # Where to store output data
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')
        # Output filename
        out_result_path = f'{output_dir}/map_trends_static_{self.job_id}.png'
        out_result_url  = f'{output_url}/map_trends_static_{self.job_id}.png'

        # Assemble arguments for R script:
        r_args = [
            in_shp_url,
            in_trend_results_url,
            in_id_trend_col,
            in_id_shp_col,
            in_group,
            in_p_value_threshold,
            in_p_value_col,
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
                    "trend_map": {
                        "title": self.metadata['outputs']['trend_map']['title'],
                        "description": self.metadata['outputs']['trend_map']['description'],
                        "href": out_result_url
                    }
                }
            }

            return 'application/json', response_object

    def __repr__(self):
        return f'<MapTrendsStaticProcessor> {self.name}'

