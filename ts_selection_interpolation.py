import logging
import subprocess
import json
import os
import requests
from urllib.parse import urlparse
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
curl --location 'http://localhost:5000/processes/ts-selection-interpolation/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://testserver.de/mean_by_group.csv",
        "rel_cols": "group_labels,HELCOM_ID",
        "missing_threshold_percentage": "40",
        "year_colname": "Year_adj_generated",
        "value_colname": "Secchi_m_mean_annual",
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

    def execute(self, data, outputs=None):

        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]
        r_script_dir = configJSON["r_script_dir"]

        # Get user inputs
        in_data_url = data.get('input_data', 'https://.../mean_by_group.csv')
        in_rel_cols = data.get('rel_cols', '')
        in_missing_threshold_percentage = data.get('missing_threshold_percentage', '')
        in_year_colname = data.get('year_colname', '')
        in_value_colname = data.get('value_colname', '')
        in_min_data_point = data.get('min_data_point', '')

        # Where to store output data
        downloadfilename = 'ts_selection_interpolation-%s.csv' % self.my_job_id # or selected_interpolated.csv ?
        downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        # Run the R script:
        R_SCRIPT_NAME = 'ts_selection_interpolation_wrapper.R'
        r_args = [in_data_url, in_rel_cols, in_missing_threshold_percentage, in_year_colname, in_value_colname, in_min_data_point, downloadfilepath]
        LOGGER.info('Run R script and store result to %s!' % downloadfilepath)
        LOGGER.debug('R args: %s' % r_args)
        exit_code, err_msg = call_r_script(LOGGER, R_SCRIPT_NAME, r_script_dir, r_args)
        LOGGER.info('Running R script done: Exit code %s' % exit_code)

        if not exit_code == 0:
            LOGGER.error(err_msg)
            raise ProcessorExecuteError(user_msg="R script failed with exit code %s" % exit_code)

        else:
            # Create download link:
            downloadlink = own_url.rstrip('/')+os.sep+downloadfilename

            # Return link to file:
            response_object = {
                "outputs": {
                    "ts_selection_interpolation": {
                        "title": "ts_selection_interpolation result table",
                        "description": "TODO must ask astra what this is",
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

    def __repr__(self):
        return f'<TsSelectionInterpolationProcessor> {self.name}'


def call_r_script(LOGGER, r_file_name, path_rscripts, r_args):
    # TODO: Move function to some module, same in all processes

    LOGGER.debug('Now calling bash which calls R: %s' % r_file_name)
    r_file = path_rscripts.rstrip('/')+os.sep+r_file_name
    cmd = ["/usr/bin/Rscript", "--vanilla", r_file] + r_args
    LOGGER.info(cmd)
    LOGGER.debug('Running command... (Output will be shown once finished)')
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    stdoutdata, stderrdata = p.communicate()
    LOGGER.debug("Done running command! Exit code from bash: %s" % p.returncode)

    ### Print stdout and stderr
    stdouttext = stdoutdata.decode()
    stderrtext = stderrdata.decode()
    if len(stderrdata) > 0:
        err_and_out = 'R stdout and stderr:\n___PROCESS OUTPUT___\n___stdout___\n{stdout}\n___stderr___\n{stderr}   (END PROCESS OUTPUT)\n___________'.format(
            stdout= stdouttext, stderr=stderrtext)
        LOGGER.error(err_and_out)
    else:
        err_and_out = 'R stdour:\n___PROCESS OUTPUT___\n___stdout___\n{stdout}\n___stderr___\n___(Nothing written to stderr)___\n   (END PROCESS OUTPUT)\n___________'.format(
            stdout = stdouttext)
        LOGGER.info(err_and_out)
    return p.returncode, err_and_out
