import logging
import subprocess
import json
import os
from pathlib import Path
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
Output file name: "data_merged_with_regions-xyz.csv"

For Helcom data, you will need to accepts the conditions first:
https://maps.helcom.fi/website/MADS/download/?id=67d653b1-aad1-4af4-920e-0683af3c4a48

Long/lat are optional

curl --location 'http://localhost:5000/processes/points-att-polygon/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "colname_long": "",
        "colname_lat": "",
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
        self.my_job_id = 'nothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<PointsAttPolygonProcessor> {self.name}'

    def execute(self, data, outputs=None):

        # Get config
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["download_url"]
        docker_executable = configJSON.get("docker_executable", "docker")

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

        downloadfilename = 'data_merged_with_regions-%s.csv' % self.my_job_id
        
        returncode, stdout, stderr = run_docker_container(
            docker_executable,
            in_regions_url, 
            in_dpoints_url, 
            in_long_col_name, 
            in_lat_col_name, 
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
                if line.startswith('Error'): # TODO: Sometimes error messages span several lines.
                    err_msg = 'Running docker container failed: %s' % (line)
            raise ProcessorExecuteError(user_msg = err_msg)

        else:
            downloadlink = own_url.rstrip('/')+os.sep+"out"+os.sep+downloadfilename
            response_object = {
                "outputs": {
                    "data_merged_with_regions": {
                        "title": self.metadata['outputs']['data_merged_with_regions']['title'],
                        "description": self.metadata['outputs']['data_merged_with_regions']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

def run_docker_container(
        docker_executable,
        regions_url, 
        dpoints_url, 
        long_col_name, 
        lat_col_name, 
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

    script = 'points_att_polygon.R'

    # Mount volumes and set command
    docker_command = [
        docker_executable, "run", "--rm", "--name", container_name,
        "-v", f"{local_out}:{container_out}",
        "-e", f"R_SCRIPT={script}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
        regions_url,
        dpoints_url,
        long_col_name,
        lat_col_name,
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
