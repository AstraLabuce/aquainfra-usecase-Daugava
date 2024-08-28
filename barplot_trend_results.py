import logging
import subprocess
import json
import os
import requests
from urllib.parse import urlparse
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
curl --location 'http://localhost:5000/processes/barplot_trend_results/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "data": "url to mk_trend_analysis_results.csv",
        "id_col": "polygon_id",
        "test_value": "Tau_Value",
        "p_value": "P_Value",
        "p_value_threshold": "0.05",
        "group": "season"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class BarplotTrendResultsProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nnothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def execute(self, data, outputs=None):
        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]
        r_script_dir = configJSON["r_script_dir"]

        # Get user inputs
        in_data = data.get('data', 'https://.../mk_trend_analysis_results.csv')
        in_id_col = data.get('id_col', 'polygon_id')
        in_test_value = data.get('test_value', 'Tau_Value')
        p_value = data.get('p_value', 'P_Value')
        in_p_value_threshold = data.get('p_value_threshold', '0.05')
        in_group = data.get('group', 'season')
        
        # Where to store output data
        downloadfilename = 'barplot_trend_results-%s.png' % self.my_job_id
        downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        # Run the R script:
        R_SCRIPT_NAME = 'barplot_trend_results_wrapper.R'
        r_args = [in_data, in_id_col, in_test_value, p_value, in_p_value_threshold, in_group, downloadfilepath]
        LOGGER.info('Run R script and store result to %s!' % downloadfilepath)
        LOGGER.debug('R args: %s' % r_args)
        exit_code, err_msg = call_r_script('1', LOGGER, R_SCRIPT_NAME, r_script_dir, r_args)
        LOGGER.info('Running R script done: Exit code %s, msg %s' % (exit_code, err_msg))

        if not exit_code == 0:
            LOGGER.error(err_msg)
            raise ProcessorExecuteError(user_msg="R script failed with exit code %s" % exit_code)

        else:
            # Create download link:
            downloadlink = own_url.rstrip('/')+os.sep+downloadfilename

            # Return link to file:
            response_object = {
                "outputs": {
                    "batplot_trend_results": {
                        "title": "barplot trend results",
                        "description": "TODO must ask astra what this is",
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

    def __repr__(self):
        return f'<BarplotTrendResultsProcessor> {self.name}'


def call_r_script(num, LOGGER, r_file_name, path_rscripts, r_args):
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
        err_and_out = 'R stdout and stderr:\n___PROCESS OUTPUT {n}___\n___stdout___\n{stdout}\n___stderr___\n{stderr}   (END PROCESS OUTPUT {n})\n___________'.format(
            stdout= stdouttext, stderr=stderrtext, n=num)
        LOGGER.error(err_and_out)
    else:
        err_and_out = 'R stdout:\n___PROCESS OUTPUT {n}___\n___stdout___\n{stdout}\n___stderr___\n___(Nothing written to stderr)___\n   (END PROCESS OUTPUT {n})\n___________'.format(
            stdout = stdouttext, n = num)
        LOGGER.info(err_and_out)
    return p.returncode, err_and_out
